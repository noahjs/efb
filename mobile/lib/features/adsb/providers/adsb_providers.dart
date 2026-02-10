import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/connection_manager.dart';
import '../services/discovery_service.dart';
import '../models/connection_state.dart';
import '../models/ownship_position.dart';
import '../models/traffic_target.dart';
import '../models/receiver_config.dart';
import '../protocol/traffic_report_decoder.dart';

// ── GPS Source preference ──

enum GpsSource { external, device }

class GpsSourceNotifier extends Notifier<GpsSource> {
  @override
  GpsSource build() => GpsSource.external;

  void set(GpsSource source) {
    state = source;
  }
}

final gpsSourceProvider =
    NotifierProvider<GpsSourceNotifier, GpsSource>(GpsSourceNotifier.new);

// ── Connection Manager (singleton) ──

final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final cm = ConnectionManager();
  ref.onDispose(() => cm.dispose());
  return cm;
});

// ── Connection Status ──

final gdl90ConnectionProvider = StreamProvider<AdsbStatus>((ref) {
  final cm = ref.watch(connectionManagerProvider);
  return cm.statusStream;
});

// ── Ownship Position ──

final ownshipPositionProvider = StreamProvider<OwnshipPosition>((ref) {
  final cm = ref.watch(connectionManagerProvider);
  int? lastGeoAlt;

  // Track latest geometric altitude from 0x0B messages
  final geoAltSub = cm.ownshipGeoAltStream.listen((alt) {
    lastGeoAlt = alt;
  });
  ref.onDispose(() => geoAltSub.cancel());

  return cm.ownshipStream.map((report) {
    return OwnshipPosition(
      latitude: report.latitude,
      longitude: report.longitude,
      pressureAltitude: report.altitude ?? 0,
      geoAltitude: lastGeoAlt,
      groundspeed: report.groundspeed ?? 0,
      track: report.track,
      verticalRate: report.verticalRate ?? 0,
      nic: report.nic,
      nacp: report.nacp,
      isAirborne: report.isAirborne,
      icaoAddress: report.icaoAddress,
      callsign: report.callsign,
      timestamp: DateTime.now(),
    );
  });
});

// ── Traffic Targets ──

class TrafficTargetsNotifier extends Notifier<Map<int, TrafficTarget>> {
  StreamSubscription<TrafficReportData>? _sub;
  Timer? _ageTimer;
  OwnshipPosition? _ownship;

  @override
  Map<int, TrafficTarget> build() {
    final cm = ref.watch(connectionManagerProvider);

    _sub = cm.trafficStream.listen(_onTraffic);
    _ageTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _ageTargets());

    // Keep ownship reference up to date for relative computations
    ref.listen(ownshipPositionProvider, (_, next) {
      next.whenData((pos) => _ownship = pos);
    });

    ref.onDispose(() {
      _sub?.cancel();
      _ageTimer?.cancel();
    });

    return {};
  }

  void _onTraffic(TrafficReportData report) {
    final now = DateTime.now();
    var target = TrafficTarget(
      icaoAddress: report.icaoAddress,
      callsign: report.callsign,
      latitude: report.latitude,
      longitude: report.longitude,
      altitude: report.altitude ?? 0,
      groundspeed: report.groundspeed ?? 0,
      track: report.track,
      verticalRate: report.verticalRate ?? 0,
      emitterCategory: report.emitterCategory,
      nic: report.nic,
      nacp: report.nacp,
      isAirborne: report.isAirborne,
      lastUpdated: now,
    );

    if (_ownship != null) {
      target = _enrichTarget(target, _ownship!);
    }

    state = {...state, report.icaoAddress: target};
  }

  TrafficTarget _enrichTarget(TrafficTarget target, OwnshipPosition ownship) {
    // Haversine distance
    final dLat = (target.latitude - ownship.latitude) * pi / 180;
    final dLon = (target.longitude - ownship.longitude) * pi / 180;
    final lat1 = ownship.latitude * pi / 180;
    final lat2 = target.latitude * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distanceNm = 3440.065 * c; // Earth radius in nautical miles

    // Bearing from ownship to target
    final y = sin(dLon) * cos(lat2);
    final x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = (atan2(y, x) * 180 / pi + 360) % 360;

    final altDelta = target.altitude - ownship.pressureAltitude;

    // Threat classification per spec
    ThreatLevel threat = ThreatLevel.none;
    if (distanceNm < 1 && altDelta.abs() < 300) {
      threat = ThreatLevel.resolution;
    } else if (distanceNm < 3 && altDelta.abs() < 600) {
      threat = ThreatLevel.alert;
    } else if (distanceNm < 6 && altDelta.abs() < 1200) {
      threat = ThreatLevel.proximate;
    }

    return target.copyWith(
      relativeBearing: bearing,
      relativeDistance: distanceNm,
      relativeAltitude: altDelta,
      threatLevel: threat,
    );
  }

  /// Remove targets not updated in the last 60 seconds.
  void _ageTargets() {
    final now = DateTime.now();
    final aged = <int, TrafficTarget>{};
    for (final entry in state.entries) {
      if (now.difference(entry.value.lastUpdated).inSeconds < 60) {
        aged[entry.key] = entry.value;
      }
    }
    if (aged.length != state.length) {
      state = aged;
    }
  }
}

final trafficTargetsProvider =
    NotifierProvider<TrafficTargetsNotifier, Map<int, TrafficTarget>>(
        TrafficTargetsNotifier.new);

// ── Derived Status (for status bar) ──

final receiverStatusProvider = Provider<AdsbStatus>((ref) {
  final connection = ref.watch(gdl90ConnectionProvider);
  final traffic = ref.watch(trafficTargetsProvider);
  final ownship = ref.watch(ownshipPositionProvider);

  return connection.when(
    data: (status) => status.copyWith(
      trafficCount: traffic.length,
      gpsPositionValid: ownship.value != null,
    ),
    loading: () => const AdsbStatus(),
    error: (_, _) =>
        const AdsbStatus(status: AdsbConnectionStatus.disconnected),
  );
});

// ── Discovery ──

final discoveryStreamProvider = StreamProvider<DiscoveredReceiver>((ref) {
  final discovery = DiscoveryService();
  ref.onDispose(() => discovery.dispose());
  discovery.startListening();
  return discovery.discoveries;
});

// ── Saved Receivers (SharedPreferences) ──

final savedReceiversProvider =
    FutureProvider<List<ReceiverConfig>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString('adsb_saved_receivers');
  if (json == null) return [];
  try {
    return ReceiverConfig.decodeList(json);
  } catch (_) {
    return [];
  }
});

/// Save a receiver config to the saved receivers list.
Future<void> saveReceiver(
    WidgetRef ref, ReceiverConfig receiver) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = await ref.read(savedReceiversProvider.future);

  // Replace if same name exists, otherwise append
  final updated = existing
      .where((r) => r.name != receiver.name)
      .toList()
    ..add(receiver);

  await prefs.setString(
      'adsb_saved_receivers', ReceiverConfig.encodeList(updated));
  ref.invalidate(savedReceiversProvider);
}

/// Remove a saved receiver by name.
Future<void> removeReceiver(WidgetRef ref, String name) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = await ref.read(savedReceiversProvider.future);
  final updated = existing.where((r) => r.name != name).toList();
  await prefs.setString(
      'adsb_saved_receivers', ReceiverConfig.encodeList(updated));
  ref.invalidate(savedReceiversProvider);
}

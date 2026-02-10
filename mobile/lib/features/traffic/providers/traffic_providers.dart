import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_client.dart';
import '../../adsb/models/connection_state.dart';
import '../../adsb/models/traffic_target.dart';
import '../../adsb/providers/adsb_providers.dart';
import '../models/traffic_settings.dart';
import '../services/traffic_api_service.dart';
import '../services/traffic_interpolation.dart';

// ── Settings ──

final trafficSettingsProvider = FutureProvider<TrafficSettings>((ref) {
  return TrafficSettings.load();
});

// ── Source Selection ──

/// Determines whether to use GDL 90 or API for traffic data.
final trafficSourceProvider = Provider<TrafficSource>((ref) {
  final settings = ref.watch(trafficSettingsProvider).value;
  if (settings != null && !settings.autoSourceSwitch) {
    return TrafficSource.api;
  }

  final connection = ref.watch(gdl90ConnectionProvider);
  final status = connection.value?.status ?? AdsbConnectionStatus.disconnected;

  if (status == AdsbConnectionStatus.connected ||
      status == AdsbConnectionStatus.stale) {
    return TrafficSource.gdl90;
  }
  return TrafficSource.api;
});

// ── API Traffic Polling ──

/// Polls the backend for traffic when the source is API.
/// Manages target lifecycle: active → stale (>20s) → expired (>60s, removed).
class ApiTrafficNotifier extends Notifier<Map<String, TrafficTarget>> {
  Timer? _pollTimer;
  TrafficApiService? _apiService;

  @override
  Map<String, TrafficTarget> build() {
    final source = ref.watch(trafficSourceProvider);
    if (source != TrafficSource.api) {
      _pollTimer?.cancel();
      return {};
    }

    final settings = ref.watch(trafficSettingsProvider).value;
    final pollInterval = settings?.pollIntervalSeconds ?? 10;
    final radius = settings?.queryRadiusNm ?? 30;

    final client = ref.read(apiClientProvider);
    _apiService = TrafficApiService(client);

    // Start polling
    _poll(radius);
    _pollTimer = Timer.periodic(
      Duration(seconds: pollInterval),
      (_) => _poll(radius),
    );

    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    return {};
  }

  Future<void> _poll(double radius) async {
    final position = ref.read(activePositionProvider);
    if (position == null) return;

    final targets = await _apiService?.fetchNearby(
      lat: position.latitude,
      lon: position.longitude,
      radiusNm: radius,
    );
    if (targets == null) return;

    final now = DateTime.now();
    final merged = <String, TrafficTarget>{};

    // Merge with existing targets (blend positions)
    for (final entry in targets.entries) {
      final old = state[entry.key];
      if (old != null) {
        merged[entry.key] =
            TrafficInterpolation.blendPosition(old, entry.value);
      } else {
        merged[entry.key] = entry.value;
      }
    }

    // Keep existing targets that weren't in this poll but aren't expired
    for (final entry in state.entries) {
      if (merged.containsKey(entry.key)) continue;
      final age = now.difference(entry.value.lastUpdated).inSeconds;
      if (age < 60) {
        merged[entry.key] = entry.value;
      }
    }

    state = merged;
  }
}

final apiTrafficProvider =
    NotifierProvider<ApiTrafficNotifier, Map<String, TrafficTarget>>(
        ApiTrafficNotifier.new);

// ── Unified Traffic ──

/// Combines GDL 90 and API traffic into a single map, with interpolation
/// and projected heads applied.
final unifiedTrafficProvider = Provider<Map<String, TrafficTarget>>((ref) {
  final source = ref.watch(trafficSourceProvider);
  final settings = ref.watch(trafficSettingsProvider).value;
  final showHeads = settings?.showHeads ?? true;
  final headIntervals = settings?.headIntervals ?? const [120, 300];
  final now = DateTime.now();

  Map<String, TrafficTarget> targets;

  if (source == TrafficSource.gdl90) {
    // Convert int-keyed GDL 90 targets to hex-string keys
    final gdl90 = ref.watch(trafficTargetsProvider);
    targets = {};
    for (final entry in gdl90.entries) {
      final hexKey = entry.key.toRadixString(16).padLeft(6, '0').toUpperCase();
      targets[hexKey] = entry.value.copyWith(source: TrafficSource.gdl90);
    }
  } else {
    targets = ref.watch(apiTrafficProvider);
  }

  // Apply interpolation and heads
  final enriched = <String, TrafficTarget>{};
  for (final entry in targets.entries) {
    var target = entry.value;

    // Extrapolate position
    final (iLat, iLon, iAlt) =
        TrafficInterpolation.extrapolatePosition(target, now);
    target = target.copyWith(
      interpolatedLat: iLat,
      interpolatedLon: iLon,
      interpolatedAlt: iAlt,
    );

    // Compute projected heads
    if (showHeads && target.groundspeed > 0) {
      final heads =
          TrafficInterpolation.computeHeads(target, headIntervals);
      target = target.copyWith(heads: heads);
    }

    enriched[entry.key] = target;
  }

  return enriched;
});

// ── Traffic GeoJSON ──

/// Builds GeoJSON FeatureCollection for traffic display on the map.
/// Includes target positions, leader lines, and projected heads.
final trafficGeoJsonProvider = Provider<Map<String, dynamic>?>((ref) {
  final targets = ref.watch(unifiedTrafficProvider);
  if (targets.isEmpty) return null;

  final settings = ref.watch(trafficSettingsProvider).value;
  final showHeads = settings?.showHeads ?? true;
  final features = <Map<String, dynamic>>[];

  for (final target in targets.values) {
    final displayLat = target.interpolatedLat ?? target.latitude;
    final displayLon = target.interpolatedLon ?? target.longitude;
    final displayAlt = target.interpolatedAlt ?? target.altitude;
    final threatStr = target.threatLevel.name;
    final label = target.callsign.isNotEmpty
        ? target.callsign
        : target.icaoAddress.toRadixString(16).toUpperCase();

    // Target point
    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [displayLon, displayLat],
      },
      'properties': {
        'featureType': 'target',
        'callsign': label,
        'threat': threatStr,
        'alt_tag': target.altitudeTag ?? '${(displayAlt / 100).round()}',
        'groundspeed': target.groundspeed,
        'track': target.track,
        'source': target.source.name,
      },
    });

    // Projected heads and leader lines
    if (showHeads && target.heads.isNotEmpty) {
      final leaderCoords = <List<double>>[
        [displayLon, displayLat],
      ];

      for (final head in target.heads) {
        // Head point
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [head.longitude, head.latitude],
          },
          'properties': {
            'featureType': 'head',
            'head_interval': head.intervalSeconds,
            'callsign': label,
            'alt_tag': head.altitude != null
                ? '${(head.altitude! / 100).round()}'
                : '',
            'threat': threatStr,
          },
        });

        leaderCoords.add([head.longitude, head.latitude]);
      }

      // Leader line
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': leaderCoords,
        },
        'properties': {
          'featureType': 'leader',
          'threat': threatStr,
        },
      });
    }
  }

  return {'type': 'FeatureCollection', 'features': features};
});

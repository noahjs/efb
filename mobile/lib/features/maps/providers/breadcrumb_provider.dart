import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../adsb/providers/adsb_providers.dart';

class TrailPoint {
  final double lat;
  final double lng;
  final int altitude;
  final int groundspeed;
  final DateTime timestamp;

  const TrailPoint({
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.groundspeed,
    required this.timestamp,
  });
}

class BreadcrumbNotifier extends Notifier<List<TrailPoint>> {
  static const _maxPoints = 3600; // ~1 hour at 1Hz
  static const _minDistanceMeters = 20.0;

  @override
  List<TrailPoint> build() {
    ref.listen(activePositionProvider, (prev, next) {
      if (next == null) return;
      _addPoint(next);
    });
    return [];
  }

  void _addPoint(dynamic pos) {
    final lat = pos.latitude as double;
    final lng = pos.longitude as double;

    // Skip if too close to last point
    if (state.isNotEmpty) {
      final last = state.last;
      final dist = _haversineMeters(last.lat, last.lng, lat, lng);
      if (dist < _minDistanceMeters) return;
    }

    final point = TrailPoint(
      lat: lat,
      lng: lng,
      altitude: pos.pressureAltitude as int,
      groundspeed: pos.groundspeed as int,
      timestamp: DateTime.now(),
    );

    if (state.length >= _maxPoints) {
      state = [...state.sublist(1), point];
    } else {
      state = [...state, point];
    }
  }

  void clear() {
    state = [];
  }

  static double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}

final breadcrumbProvider =
    NotifierProvider<BreadcrumbNotifier, List<TrailPoint>>(
        BreadcrumbNotifier.new);

/// Derived provider converting trail points to GeoJSON LineString.
final breadcrumbGeoJsonProvider = Provider<Map<String, dynamic>?>((ref) {
  final points = ref.watch(breadcrumbProvider);
  if (points.length < 2) return null;

  final coordinates = points.map((p) => [p.lng, p.lat]).toList();
  return {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': coordinates,
        },
        'properties': {},
      },
    ],
  };
});

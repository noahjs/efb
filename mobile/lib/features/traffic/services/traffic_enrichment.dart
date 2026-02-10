import 'dart:math';

import '../../adsb/models/ownship_position.dart';
import '../../adsb/models/traffic_target.dart';

/// Shared traffic enrichment utilities used by both GDL 90 and API paths.
class TrafficEnrichment {
  TrafficEnrichment._();

  /// ADS-B emitter category string → integer mapping.
  static const _categoryToInt = <String, int>{
    'A0': 0,
    'A1': 1,
    'A2': 2,
    'A3': 3,
    'A4': 4,
    'A5': 5,
    'A6': 6,
    'A7': 7,
    'B0': 8,
    'B1': 9,
    'B2': 10,
    'B3': 11,
    'B4': 12,
    'B5': 13,
    'B6': 14,
    'B7': 15,
    'C0': 16,
    'C1': 17,
    'C2': 18,
    'C3': 19,
  };

  /// Human-readable labels for emitter categories.
  static const categoryLabels = <int, String>{
    1: 'Light Aircraft',
    2: 'Small Aircraft',
    3: 'Large Aircraft',
    4: 'High Vortex',
    5: 'Heavy',
    6: 'High Performance',
    7: 'Helicopter',
    9: 'Glider',
    10: 'Lighter-than-Air',
    12: 'Skydiver',
    14: 'UAV',
  };

  /// Convert ADS-B category string (e.g. "A7") to integer.
  static int categoryStringToInt(String category) {
    return _categoryToInt[category.toUpperCase()] ?? 0;
  }

  /// Get a display label for an emitter category integer.
  static String categoryLabel(int category) {
    return categoryLabels[category] ?? 'Traffic';
  }

  /// Enrich a [TrafficTarget] with ownship-relative data:
  /// bearing, distance, altitude delta, and threat level.
  static TrafficTarget enrichWithOwnship(
    TrafficTarget target,
    OwnshipPosition ownship,
  ) {
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
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = (atan2(y, x) * 180 / pi + 360) % 360;

    // Only compute relative altitude when ownship has a valid altitude
    final hasOwnAlt = ownship.pressureAltitude != 0;
    final altDelta = hasOwnAlt
        ? target.altitude - ownship.pressureAltitude
        : null;

    // Threat classification (skip altitude check when ownship alt unknown)
    ThreatLevel threat = ThreatLevel.none;
    if (altDelta != null) {
      if (distanceNm < 1 && altDelta.abs() < 300) {
        threat = ThreatLevel.resolution;
      } else if (distanceNm < 3 && altDelta.abs() < 600) {
        threat = ThreatLevel.alert;
      } else if (distanceNm < 6 && altDelta.abs() < 1200) {
        threat = ThreatLevel.proximate;
      }
    }

    return target.copyWith(
      relativeBearing: bearing,
      relativeDistance: distanceNm,
      relativeAltitude: altDelta,
      threatLevel: threat,
    );
  }

  /// Convert an absolute bearing and ownship track to a clock position (1-12).
  static int clockPosition(double absoluteBearing, int ownshipTrack) {
    final relative = (absoluteBearing - ownshipTrack + 360) % 360;
    var clock = (relative / 30).round();
    if (clock == 0) clock = 12;
    return clock;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adsb/models/traffic_target.dart';
import '../../adsb/providers/adsb_providers.dart';
import '../services/traffic_enrichment.dart';
import 'traffic_providers.dart';

/// A proximity alert for display on the map.
class TrafficAlert {
  /// Human-readable alert message, e.g. "Helicopter Below 500 ft, 11 o'clock"
  final String message;

  /// Threat level for color coding the banner.
  final ThreatLevel threat;

  /// ICAO hex key of the alerting target.
  final String targetId;

  /// Distance in nautical miles.
  final double distanceNm;

  const TrafficAlert({
    required this.message,
    required this.threat,
    required this.targetId,
    required this.distanceNm,
  });
}

/// Provides a proximity alert for the closest threatening traffic target.
/// Returns null when no traffic is within the alert thresholds.
final trafficAlertProvider = Provider<TrafficAlert?>((ref) {
  final settings = ref.watch(trafficSettingsProvider).value;
  if (settings == null || !settings.proximityAlerts) return null;

  final targets = ref.watch(unifiedTrafficProvider);
  final ownship = ref.watch(activePositionProvider);
  if (ownship == null || targets.isEmpty) return null;

  String? closestKey;
  double closestDist = double.infinity;

  for (final entry in targets.entries) {
    final t = entry.value;
    final dist = t.relativeDistance;
    final altDelta = t.relativeAltitude;
    if (dist == null || altDelta == null) continue;

    // Alert thresholds: within 2 nm horizontal, 2000 ft vertical
    if (dist < 2 && altDelta.abs() < 2000 && dist < closestDist) {
      closestDist = dist;
      closestKey = entry.key;
    }
  }

  if (closestKey == null) return null;

  final target = targets[closestKey]!;
  final altDelta = target.relativeAltitude!;
  final bearing = target.relativeBearing ?? 0;

  // Aircraft type label from emitter category
  final typeLabel = TrafficEnrichment.categoryLabel(target.emitterCategory);

  // Relative altitude description
  String altDesc;
  if (altDelta.abs() < 100) {
    altDesc = 'Co-altitude';
  } else if (altDelta > 0) {
    altDesc = 'Above ${altDelta.abs()} ft';
  } else {
    altDesc = 'Below ${altDelta.abs()} ft';
  }

  // Clock position
  final clock = TrafficEnrichment.clockPosition(bearing, ownship.track);

  // Build message
  String message;
  if (altDelta.abs() < 100) {
    message = '$typeLabel $altDesc, $clock o\'clock';
  } else {
    message = '$typeLabel $altDesc, $clock o\'clock';
  }

  // Threat level: red for < 1nm, amber for < 2nm
  final threat = closestDist < 1 ? ThreatLevel.resolution : ThreatLevel.alert;

  return TrafficAlert(
    message: message,
    threat: threat,
    targetId: closestKey,
    distanceNm: closestDist,
  );
});

import 'dart:math';

import '../../adsb/models/traffic_target.dart';
import '../models/projected_head.dart';

/// Dead-reckoning and interpolation utilities for traffic targets.
/// All functions are pure (no state).
class TrafficInterpolation {
  const TrafficInterpolation._();

  /// Maximum time to extrapolate ahead (seconds).
  static const _maxExtrapolationSec = 15;

  /// Maximum error (nm) before snapping instead of blending.
  static const _blendThresholdNm = 0.5;

  /// Extrapolate a target's position from its last known state to [now].
  /// Returns (lat, lon, alt). Caps extrapolation at [_maxExtrapolationSec].
  static (double lat, double lon, int alt) extrapolatePosition(
    TrafficTarget target,
    DateTime now,
  ) {
    final elapsed = now.difference(target.lastUpdated);
    final sec = elapsed.inMilliseconds / 1000.0;
    final clampedSec = sec.clamp(0.0, _maxExtrapolationSec.toDouble());

    if (clampedSec <= 0 || target.groundspeed <= 0) {
      return (target.latitude, target.longitude, target.altitude);
    }

    return _project(
      target.latitude,
      target.longitude,
      target.altitude,
      target.groundspeed,
      target.track,
      target.verticalRate,
      clampedSec,
    );
  }

  /// Compute projected heads at each interval (in seconds) from the
  /// target's current position.
  static List<ProjectedHead> computeHeads(
    TrafficTarget target,
    List<int> intervals,
  ) {
    if (target.groundspeed <= 0) return [];

    return intervals.map((sec) {
      final (lat, lon, alt) = _project(
        target.latitude,
        target.longitude,
        target.altitude,
        target.groundspeed,
        target.track,
        target.verticalRate,
        sec.toDouble(),
      );
      return ProjectedHead(
        intervalSeconds: sec,
        latitude: lat,
        longitude: lon,
        altitude: alt,
      );
    }).toList();
  }

  /// Blend old and new positions. If error < threshold, returns the updated
  /// target as-is (allowing smooth interpolation to handle the transition).
  /// If error is large, snaps to the new position immediately.
  static TrafficTarget blendPosition(
    TrafficTarget old,
    TrafficTarget updated,
  ) {
    final distNm = _haversineNm(
      old.latitude,
      old.longitude,
      updated.latitude,
      updated.longitude,
    );

    // Small error — the interpolation engine will smoothly transition
    if (distNm < _blendThresholdNm) {
      return updated;
    }

    // Large error — snap (no interpolation state carried over)
    return updated.copyWith(
      interpolatedLat: null,
      interpolatedLon: null,
      interpolatedAlt: null,
    );
  }

  /// Dead-reckoning projection from a point along a track.
  static (double lat, double lon, int alt) _project(
    double lat,
    double lon,
    int altitude,
    int groundspeedKt,
    int trackDeg,
    int verticalRateFpm,
    double seconds,
  ) {
    final distNm = groundspeedKt * (seconds / 3600.0);
    final trackRad = trackDeg * pi / 180.0;
    final latRad = lat * pi / 180.0;

    final newLat = lat + (distNm / 60.0) * cos(trackRad);
    final newLon =
        lon + (distNm / (60.0 * cos(latRad))) * sin(trackRad);
    final newAlt = altitude + (verticalRateFpm * seconds / 60.0).round();

    return (newLat, newLon, newAlt);
  }

  /// Haversine distance in nautical miles.
  static double _haversineNm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusNm = 3440.065;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusNm * c;
  }
}

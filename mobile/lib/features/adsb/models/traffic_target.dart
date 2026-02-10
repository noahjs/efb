import '../../traffic/models/projected_head.dart';

/// Threat level classification based on proximity to ownship.
enum ThreatLevel {
  /// No threat — beyond proximity thresholds.
  none,

  /// Proximate — within 6 nm horizontal and 1,200 ft vertical.
  proximate,

  /// Alert — within 3 nm horizontal and 600 ft vertical.
  alert,

  /// Resolution — within 1 nm horizontal and 300 ft vertical.
  resolution,
}

/// Source of traffic data.
enum TrafficSource {
  /// GDL 90 ADS-B receiver (physical device).
  gdl90,

  /// Internet API (e.g. Airplanes.live).
  api,
}

/// A single ADS-B traffic target decoded from GDL 90 Traffic Report (0x14).
///
/// In-memory only — not persisted to database.
class TrafficTarget {
  /// ICAO Mode S address (24-bit) — primary key for deduplication.
  final int icaoAddress;

  /// Callsign / tail number (space-trimmed).
  final String callsign;

  final double latitude;
  final double longitude;

  /// Pressure altitude in feet MSL.
  final int altitude;

  /// Groundspeed in knots.
  final int groundspeed;

  /// Track angle in degrees true (0-359).
  final int track;

  /// Vertical rate in feet per minute (signed).
  final int verticalRate;

  /// Emitter category (light, large, heavy, rotorcraft, etc.).
  final int emitterCategory;

  /// Navigation Integrity Category (0-11).
  final int nic;

  /// Navigation Accuracy Category for Position (0-11).
  final int nacp;

  /// Whether the target is airborne.
  final bool isAirborne;

  /// When this target was last updated.
  final DateTime lastUpdated;

  // ── Computed relative fields (set by TrafficTargetsNotifier) ──

  /// Bearing from ownship to this target in degrees true.
  final double? relativeBearing;

  /// Distance from ownship in nautical miles.
  final double? relativeDistance;

  /// Altitude difference from ownship in feet (positive = above).
  final int? relativeAltitude;

  /// Threat classification based on proximity.
  final ThreatLevel threatLevel;

  /// Data source for this target.
  final TrafficSource source;

  /// Interpolated position for smooth rendering between polls.
  final double? interpolatedLat;
  final double? interpolatedLon;
  final int? interpolatedAlt;

  /// Projected future positions (e.g. 2-min, 5-min heads).
  final List<ProjectedHead> heads;

  /// How stale the source position data was when received.
  final Duration? positionAge;

  const TrafficTarget({
    required this.icaoAddress,
    required this.callsign,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.groundspeed,
    required this.track,
    required this.verticalRate,
    required this.emitterCategory,
    required this.nic,
    required this.nacp,
    required this.isAirborne,
    required this.lastUpdated,
    this.relativeBearing,
    this.relativeDistance,
    this.relativeAltitude,
    this.threatLevel = ThreatLevel.none,
    this.source = TrafficSource.gdl90,
    this.interpolatedLat,
    this.interpolatedLon,
    this.interpolatedAlt,
    this.heads = const [],
    this.positionAge,
  });

  TrafficTarget copyWith({
    int? icaoAddress,
    String? callsign,
    double? latitude,
    double? longitude,
    int? altitude,
    int? groundspeed,
    int? track,
    int? verticalRate,
    int? emitterCategory,
    int? nic,
    int? nacp,
    bool? isAirborne,
    DateTime? lastUpdated,
    double? relativeBearing,
    double? relativeDistance,
    int? relativeAltitude,
    ThreatLevel? threatLevel,
    TrafficSource? source,
    double? interpolatedLat,
    double? interpolatedLon,
    int? interpolatedAlt,
    List<ProjectedHead>? heads,
    Duration? positionAge,
  }) {
    return TrafficTarget(
      icaoAddress: icaoAddress ?? this.icaoAddress,
      callsign: callsign ?? this.callsign,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      groundspeed: groundspeed ?? this.groundspeed,
      track: track ?? this.track,
      verticalRate: verticalRate ?? this.verticalRate,
      emitterCategory: emitterCategory ?? this.emitterCategory,
      nic: nic ?? this.nic,
      nacp: nacp ?? this.nacp,
      isAirborne: isAirborne ?? this.isAirborne,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      relativeBearing: relativeBearing ?? this.relativeBearing,
      relativeDistance: relativeDistance ?? this.relativeDistance,
      relativeAltitude: relativeAltitude ?? this.relativeAltitude,
      threatLevel: threatLevel ?? this.threatLevel,
      source: source ?? this.source,
      interpolatedLat: interpolatedLat ?? this.interpolatedLat,
      interpolatedLon: interpolatedLon ?? this.interpolatedLon,
      interpolatedAlt: interpolatedAlt ?? this.interpolatedAlt,
      heads: heads ?? this.heads,
      positionAge: positionAge ?? this.positionAge,
    );
  }

  /// Relative altitude formatted for map label (e.g. "+3", "-12").
  /// Hundreds of feet, rounded. Null if no ownship reference.
  String? get altitudeTag {
    if (relativeAltitude == null) return null;
    final hundreds = (relativeAltitude! / 100).round();
    if (hundreds == 0) return '0';
    return hundreds > 0 ? '+$hundreds' : '$hundreds';
  }

  @override
  String toString() =>
      'TrafficTarget(${icaoAddress.toRadixString(16)}, $callsign, '
      '${altitude}ft, $threatLevel)';
}

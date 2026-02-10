/// Ownship GPS position decoded from GDL 90 Ownship Report (0x0A)
/// and optionally enriched with Ownship Geometric Altitude (0x0B).
class OwnshipPosition {
  final double latitude;
  final double longitude;

  /// Pressure altitude in feet MSL (from 0x0A report).
  final int pressureAltitude;

  /// GPS geometric altitude in feet MSL (from 0x0B, if available).
  final int? geoAltitude;

  /// Groundspeed in knots.
  final int groundspeed;

  /// Track angle in degrees true (0-359).
  final int track;

  /// Vertical rate in feet per minute (signed).
  final int verticalRate;

  /// Navigation Integrity Category (0-11).
  final int nic;

  /// Navigation Accuracy Category for Position (0-11).
  final int nacp;

  /// Whether the aircraft is airborne.
  final bool isAirborne;

  /// ICAO Mode S address (24-bit).
  final int icaoAddress;

  /// Callsign / tail number.
  final String callsign;

  /// When this position was received.
  final DateTime timestamp;

  const OwnshipPosition({
    required this.latitude,
    required this.longitude,
    required this.pressureAltitude,
    this.geoAltitude,
    required this.groundspeed,
    required this.track,
    required this.verticalRate,
    required this.nic,
    required this.nacp,
    required this.isAirborne,
    required this.icaoAddress,
    required this.callsign,
    required this.timestamp,
  });

  OwnshipPosition copyWith({
    double? latitude,
    double? longitude,
    int? pressureAltitude,
    int? geoAltitude,
    int? groundspeed,
    int? track,
    int? verticalRate,
    int? nic,
    int? nacp,
    bool? isAirborne,
    int? icaoAddress,
    String? callsign,
    DateTime? timestamp,
  }) {
    return OwnshipPosition(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pressureAltitude: pressureAltitude ?? this.pressureAltitude,
      geoAltitude: geoAltitude ?? this.geoAltitude,
      groundspeed: groundspeed ?? this.groundspeed,
      track: track ?? this.track,
      verticalRate: verticalRate ?? this.verticalRate,
      nic: nic ?? this.nic,
      nacp: nacp ?? this.nacp,
      isAirborne: isAirborne ?? this.isAirborne,
      icaoAddress: icaoAddress ?? this.icaoAddress,
      callsign: callsign ?? this.callsign,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() =>
      'OwnshipPosition($latitude, $longitude, ${pressureAltitude}ft, '
      '${groundspeed}kt, ${track}deg)';
}

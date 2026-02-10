import 'dart:typed_data';

/// Raw decoded data from a 28-byte GDL 90 traffic/ownship report.
///
/// Used for both Ownship Report (0x0A) and Traffic Report (0x14) —
/// they share the identical 28-byte format.
class TrafficReportData {
  final int addressType;
  final int icaoAddress;
  final double latitude;
  final double longitude;
  final int? altitude;
  final bool isAirborne;
  final int nic;
  final int nacp;
  final int? groundspeed;
  final int? verticalRate;
  final int track;
  final int emitterCategory;
  final String callsign;
  final int emergencyCode;

  const TrafficReportData({
    required this.addressType,
    required this.icaoAddress,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.isAirborne,
    required this.nic,
    required this.nacp,
    required this.groundspeed,
    required this.verticalRate,
    required this.track,
    required this.emitterCategory,
    required this.callsign,
    required this.emergencyCode,
  });

  @override
  String toString() =>
      'TrafficReportData(${icaoAddress.toRadixString(16)}, $callsign, '
      '$latitude, $longitude, ${altitude}ft)';
}

/// Decodes the 28-byte traffic/ownship report payload from GDL 90.
///
/// Reference: GDL 90 Data Interface Specification, Section 3.5.
class TrafficReportDecoder {
  TrafficReportDecoder._();

  /// Decode a 28-byte traffic or ownship report [payload].
  ///
  /// Returns `null` if the payload length is not 28 bytes.
  static TrafficReportData? decode(Uint8List payload) {
    if (payload.length != 28) return null;

    // Byte 0: Status — upper 4 bits = address type, lower 4 = alert status
    final addressType = (payload[0] >> 4) & 0x0F;

    // Bytes 1-3: Participant address (24-bit ICAO Mode S, big-endian)
    final icaoAddress =
        (payload[1] << 16) | (payload[2] << 8) | payload[3];

    // Bytes 4-6: Latitude (signed 24-bit, 180/2^23 degrees per LSB)
    int rawLat = (payload[4] << 16) | (payload[5] << 8) | payload[6];
    if (rawLat >= 0x800000) rawLat -= 0x1000000; // sign-extend 24-bit
    final latitude = rawLat * (180.0 / (1 << 23));

    // Bytes 7-9: Longitude (signed 24-bit, 180/2^23 degrees per LSB)
    int rawLon = (payload[7] << 16) | (payload[8] << 8) | payload[9];
    if (rawLon >= 0x800000) rawLon -= 0x1000000;
    final longitude = rawLon * (180.0 / (1 << 23));

    // Bytes 10-11 upper 12 bits: Altitude (25 ft/LSB, offset -1000 ft)
    final altRaw = (payload[10] << 4) | ((payload[11] >> 4) & 0x0F);
    final altitudeValid = altRaw != 0xFFF;
    final altitude = altitudeValid ? (altRaw * 25) - 1000 : null;

    // Byte 11 lower 4 bits: Misc — bit 3 indicates airborne
    final misc = payload[11] & 0x0F;
    final isAirborne = (misc & 0x08) != 0;

    // Byte 12: NIC (upper 4 bits) + NACp (lower 4 bits)
    final nic = (payload[12] >> 4) & 0x0F;
    final nacp = payload[12] & 0x0F;

    // Bytes 13-14 upper 12 bits: Horizontal velocity (knots)
    final hvelRaw = (payload[13] << 4) | ((payload[14] >> 4) & 0x0F);
    final groundspeed = hvelRaw != 0xFFF ? hvelRaw : null;

    // Bytes 14-15 lower 12 bits: Vertical velocity (64 fpm/LSB, signed)
    int vvelRaw = ((payload[14] & 0x0F) << 8) | payload[15];
    final vvelValid = vvelRaw != 0x800;
    if (vvelValid && vvelRaw >= 0x800) {
      vvelRaw -= 0x1000; // sign-extend 12-bit
    }
    final verticalRate = vvelValid ? vvelRaw * 64 : null;

    // Byte 16: Track/heading (360/256 degrees per LSB)
    final track = (payload[16] * 360.0 / 256.0).round() % 360;

    // Byte 17: Emitter category
    final emitterCategory = payload[17];

    // Bytes 18-25: Callsign (8 bytes ASCII, space-padded)
    final callsignBytes = payload.sublist(18, 26);
    final callsign = String.fromCharCodes(callsignBytes).trim();

    // Byte 26: Emergency code (upper 4 bits) + spare (lower 4 bits)
    final emergencyCode = (payload[26] >> 4) & 0x0F;

    return TrafficReportData(
      addressType: addressType,
      icaoAddress: icaoAddress,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      isAirborne: isAirborne,
      nic: nic,
      nacp: nacp,
      groundspeed: groundspeed,
      verticalRate: verticalRate,
      track: track,
      emitterCategory: emitterCategory,
      callsign: callsign,
      emergencyCode: emergencyCode,
    );
  }
}

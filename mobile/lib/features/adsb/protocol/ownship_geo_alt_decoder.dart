import 'dart:typed_data';

/// Decodes GDL 90 Ownship Geometric Altitude messages (ID 0x0B, 5-byte payload).
///
/// Provides GPS-derived geometric altitude at 5-foot resolution,
/// complementing the pressure altitude from the Ownship Report (0x0A).
///
/// Reference: GDL 90 Data Interface Specification, Section 3.6.
class OwnshipGeoAltDecoder {
  OwnshipGeoAltDecoder._();

  /// Decode a 5-byte geometric altitude [payload].
  ///
  /// Returns the geometric altitude in feet MSL, or `null` if invalid.
  static int? decode(Uint8List payload) {
    if (payload.length < 2) return null;

    // Bytes 0-1: Geometric altitude (signed 16-bit, 5 ft per LSB)
    int rawAlt = (payload[0] << 8) | payload[1];
    if (rawAlt >= 0x8000) rawAlt -= 0x10000; // sign-extend 16-bit
    return rawAlt * 5;
  }
}

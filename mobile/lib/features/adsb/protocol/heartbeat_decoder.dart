import 'dart:typed_data';

import '../models/heartbeat_data.dart';

/// Decodes GDL 90 Heartbeat messages (message ID 0x00, 7-byte payload).
///
/// Reference: GDL 90 Data Interface Specification, Section 3.1.
class HeartbeatDecoder {
  HeartbeatDecoder._();

  /// Decode a heartbeat [payload] (7 bytes).
  ///
  /// Returns `null` if the payload is too short.
  static HeartbeatData? decode(Uint8List payload) {
    if (payload.length < 5) return null;

    final status1 = payload[0];
    final status2 = payload[1];

    // Status byte 1, bit 7: GPS position valid
    final gpsPositionValid = (status1 & 0x80) != 0;

    // Status byte 1, bit 0: UAT initialized
    final uatInitialized = (status1 & 0x01) != 0;

    // Status byte 2, bit 0: UTC OK
    final utcOk = (status2 & 0x01) != 0;

    // Timestamp: status2 bit 7 is MSB (bit 16), then bytes 2-3 as 16-bit
    final tsMsb = (status2 >> 7) & 0x01;
    final ts16 = (payload[2] << 8) | payload[3];
    final timestampSeconds = (tsMsb << 16) | ts16;

    return HeartbeatData(
      gpsPositionValid: gpsPositionValid,
      uatInitialized: uatInitialized,
      utcOk: utcOk,
      timestampSeconds: timestampSeconds,
      receivedAt: DateTime.now(),
    );
  }
}

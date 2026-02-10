import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/adsb/protocol/heartbeat_decoder.dart';

void main() {
  group('HeartbeatDecoder', () {
    test('decodes GPS position valid flag', () {
      // Status byte 1: bit 7 set = GPS valid
      final payload = Uint8List.fromList([0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload)!;
      expect(hb.gpsPositionValid, true);

      // Status byte 1: bit 7 clear = GPS invalid
      final payload2 = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final hb2 = HeartbeatDecoder.decode(payload2)!;
      expect(hb2.gpsPositionValid, false);
    });

    test('decodes UAT initialized flag', () {
      // Status byte 1: bit 0 set = UAT init
      final payload = Uint8List.fromList([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload)!;
      expect(hb.uatInitialized, true);

      final payload2 = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final hb2 = HeartbeatDecoder.decode(payload2)!;
      expect(hb2.uatInitialized, false);
    });

    test('decodes UTC OK flag', () {
      // Status byte 2: bit 0 set = UTC OK
      final payload = Uint8List.fromList([0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload)!;
      expect(hb.utcOk, true);
    });

    test('decodes timestamp', () {
      // Timestamp = 43200 seconds (12:00:00 UTC)
      // 43200 = 0xA8C0
      // Status byte 2 bit 7 = 0 (MSB), bytes 2-3 = 0xA8C0
      final payload = Uint8List.fromList([0x00, 0x00, 0xA8, 0xC0, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload)!;
      expect(hb.timestampSeconds, 43200);
    });

    test('decodes timestamp with MSB in status byte 2', () {
      // Timestamp = 86400 - 1 = 86399 = 0x15180 - 1 = 0x1517F
      // Actually, max seconds = 86399 = 0x1517F
      // Bit 16 (MSB) = 1, lower 16 bits = 0x517F
      // Status byte 2 bit 7 = 1
      final payload = Uint8List.fromList([0x00, 0x80, 0x51, 0x7F, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload)!;
      expect(hb.timestampSeconds, 86399);
    });

    test('decodes combined flags', () {
      // GPS valid (0x80) + UAT init (0x01) = 0x81
      // UTC OK (0x01)
      final payload = Uint8List.fromList([0x81, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload)!;
      expect(hb.gpsPositionValid, true);
      expect(hb.uatInitialized, true);
      expect(hb.utcOk, true);
    });

    test('returns null for too-short payload', () {
      expect(HeartbeatDecoder.decode(Uint8List(4)), isNull);
      expect(HeartbeatDecoder.decode(Uint8List(0)), isNull);
    });

    test('accepts minimum 5-byte payload', () {
      final payload = Uint8List.fromList([0x80, 0x01, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload);
      expect(hb, isNotNull);
      expect(hb!.gpsPositionValid, true);
    });

    test('sets receivedAt to approximately now', () {
      final before = DateTime.now();
      final payload = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final hb = HeartbeatDecoder.decode(payload)!;
      final after = DateTime.now();

      expect(hb.receivedAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(hb.receivedAt.isBefore(after.add(const Duration(seconds: 1))), true);
    });
  });
}

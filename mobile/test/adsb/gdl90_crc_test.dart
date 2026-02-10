import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/adsb/protocol/gdl90_crc.dart';

void main() {
  group('Gdl90Crc', () {
    test('compute returns 0 for empty data', () {
      expect(Gdl90Crc.compute([]), 0);
    });

    test('compute produces consistent results', () {
      final data = [0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02];
      final crc1 = Gdl90Crc.compute(data);
      final crc2 = Gdl90Crc.compute(data);
      expect(crc1, crc2);
    });

    test('compute produces non-zero CRC for typical data', () {
      // CRC of [0x01] should be non-zero (0x00 happens to CRC to 0)
      expect(Gdl90Crc.compute([0x01]), isNot(0));
    });

    test('validate returns true for correct FCS', () {
      // Build a message with correct CRC appended
      final payload = [0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02];
      final crc = Gdl90Crc.compute(payload);
      final fcsLo = crc & 0xFF;
      final fcsHi = (crc >> 8) & 0xFF;
      final messageWithFcs = [...payload, fcsLo, fcsHi];

      expect(Gdl90Crc.validate(messageWithFcs), true);
    });

    test('validate returns false for incorrect FCS', () {
      final payload = [0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02];
      // Append wrong CRC
      final messageWithFcs = [...payload, 0x00, 0x00];

      expect(Gdl90Crc.validate(messageWithFcs), false);
    });

    test('validate returns false for too-short data', () {
      expect(Gdl90Crc.validate([0x00, 0x01]), false);
      expect(Gdl90Crc.validate([0x00]), false);
      expect(Gdl90Crc.validate([]), false);
    });

    test('validate handles single-byte message', () {
      // Single byte message ID, no payload, just CRC
      final payload = [0x00];
      final crc = Gdl90Crc.compute(payload);
      final fcsLo = crc & 0xFF;
      final fcsHi = (crc >> 8) & 0xFF;
      final messageWithFcs = [0x00, fcsLo, fcsHi];

      expect(Gdl90Crc.validate(messageWithFcs), true);
    });

    test('different payloads produce different CRCs', () {
      final crc1 = Gdl90Crc.compute([0x00, 0x01, 0x02]);
      final crc2 = Gdl90Crc.compute([0x00, 0x01, 0x03]);
      expect(crc1, isNot(crc2));
    });
  });
}

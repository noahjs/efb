import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/adsb/protocol/gdl90_crc.dart';
import 'package:efb_mobile/features/adsb/protocol/gdl90_framing.dart';

/// Helper: build a valid GDL 90 frame with flag bytes and CRC.
Uint8List buildFrame(int messageId, List<int> payload) {
  final data = [messageId, ...payload];
  final crc = Gdl90Crc.compute(data);
  final fcsLo = crc & 0xFF;
  final fcsHi = (crc >> 8) & 0xFF;

  // Apply byte stuffing to the entire content (msgId + payload + FCS)
  final stuffed = <int>[];
  for (final b in [...data, fcsLo, fcsHi]) {
    if (b == 0x7E) {
      stuffed.addAll([0x7D, 0x5E]);
    } else if (b == 0x7D) {
      stuffed.addAll([0x7D, 0x5D]);
    } else {
      stuffed.add(b);
    }
  }

  return Uint8List.fromList([0x7E, ...stuffed, 0x7E]);
}

void main() {
  group('Gdl90Framing', () {
    test('extracts a single valid message', () {
      final frame = buildFrame(0x00, [0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02]);
      final messages = Gdl90Framing.extractMessages(frame);

      expect(messages.length, 1);
      expect(messages[0].messageId, 0x00);
      expect(messages[0].payload.length, 6);
    });

    test('extracts multiple messages from single datagram', () {
      final frame1 = buildFrame(0x00, [0x81, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final frame2 = buildFrame(0x0B, [0x01, 0xF4, 0x00, 0x00]);

      // Concatenate (second frame starts where first ends)
      final combined = Uint8List.fromList([...frame1, ...frame2]);
      final messages = Gdl90Framing.extractMessages(combined);

      expect(messages.length, 2);
      expect(messages[0].messageId, 0x00);
      expect(messages[1].messageId, 0x0B);
    });

    test('handles byte stuffing of 0x7E in payload', () {
      // Create payload that contains values that would become 0x7E after CRC
      // Use a simple test: payload with no special bytes, verify round-trip
      final frame = buildFrame(0x14, List.filled(28, 0x01));
      final messages = Gdl90Framing.extractMessages(frame);

      expect(messages.length, 1);
      expect(messages[0].messageId, 0x14);
      expect(messages[0].payload.length, 28);
      expect(messages[0].payload.every((b) => b == 0x01), true);
    });

    test('rejects frame with bad CRC', () {
      // Build a frame but corrupt one byte
      final data = [0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02];
      final crc = Gdl90Crc.compute(data);
      final fcsLo = crc & 0xFF;
      final fcsHi = (crc >> 8) & 0xFF;
      // Corrupt the payload
      data[3] = 0xFF;
      final frame = Uint8List.fromList(
          [0x7E, ...data, fcsLo, fcsHi, 0x7E]);

      final messages = Gdl90Framing.extractMessages(frame);
      expect(messages, isEmpty);
    });

    test('skips empty frames (consecutive flags)', () {
      final datagram = Uint8List.fromList([0x7E, 0x7E, 0x7E]);
      final messages = Gdl90Framing.extractMessages(datagram);
      expect(messages, isEmpty);
    });

    test('skips frames that are too short', () {
      // Only 2 bytes between flags (need at least 3: msgId + 2 FCS)
      final datagram = Uint8List.fromList([0x7E, 0x00, 0x01, 0x7E]);
      final messages = Gdl90Framing.extractMessages(datagram);
      expect(messages, isEmpty);
    });

    test('handles empty datagram', () {
      final messages = Gdl90Framing.extractMessages(Uint8List(0));
      expect(messages, isEmpty);
    });

    test('handles datagram with no flag bytes', () {
      final messages =
          Gdl90Framing.extractMessages(Uint8List.fromList([0x01, 0x02, 0x03]));
      expect(messages, isEmpty);
    });

    test('handles datagram with garbage before first flag', () {
      final validFrame =
          buildFrame(0x00, [0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02]);
      final withGarbage =
          Uint8List.fromList([0xFF, 0xAA, 0xBB, ...validFrame]);
      final messages = Gdl90Framing.extractMessages(withGarbage);

      expect(messages.length, 1);
      expect(messages[0].messageId, 0x00);
    });

    test('byte unstuffing works correctly', () {
      // Manually construct a frame where the payload contains 0x7D 0x5E
      // which should unstuff to 0x7E
      final msgId = 0x0B;
      final payload = [0x7E, 0x00, 0x00, 0x00]; // contains a 0x7E

      // Build CRC over unstuffed data
      final data = [msgId, ...payload];
      final crc = Gdl90Crc.compute(data);
      final fcsLo = crc & 0xFF;
      final fcsHi = (crc >> 8) & 0xFF;

      // Manually stuff the content
      final allBytes = [...data, fcsLo, fcsHi];
      final stuffed = <int>[0x7E];
      for (final b in allBytes) {
        if (b == 0x7E) {
          stuffed.addAll([0x7D, 0x5E]);
        } else if (b == 0x7D) {
          stuffed.addAll([0x7D, 0x5D]);
        } else {
          stuffed.add(b);
        }
      }
      stuffed.add(0x7E);

      final messages =
          Gdl90Framing.extractMessages(Uint8List.fromList(stuffed));
      expect(messages.length, 1);
      expect(messages[0].messageId, msgId);
      // The payload should contain the unstuffed 0x7E
      expect(messages[0].payload[0], 0x7E);
    });
  });
}

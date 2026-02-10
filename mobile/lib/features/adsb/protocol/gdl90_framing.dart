import 'dart:typed_data';

import 'gdl90_crc.dart';

/// A single GDL 90 message extracted from a UDP datagram.
class Gdl90Frame {
  /// The message type identifier (first byte after the start flag).
  final int messageId;

  /// The payload bytes after the message ID and before the FCS.
  final Uint8List payload;

  const Gdl90Frame({required this.messageId, required this.payload});

  @override
  String toString() =>
      'Gdl90Frame(id: 0x${messageId.toRadixString(16).padLeft(2, '0')}, '
      'len: ${payload.length})';
}

/// Extracts and validates GDL 90 messages from raw UDP datagrams.
///
/// GDL 90 uses asynchronous HDLC framing:
/// - Flag byte `0x7E` marks start and end of each message
/// - Escape byte `0x7D`: `0x7D 0x5E` → `0x7E`, `0x7D 0x5D` → `0x7D`
/// - 16-bit CRC-CCITT FCS appended before trailing flag (low byte first)
///
/// A single UDP datagram may contain multiple flag-delimited messages.
class Gdl90Framing {
  Gdl90Framing._();

  static const int _flagByte = 0x7E;
  static const int _escapeByte = 0x7D;

  /// Extract all valid GDL 90 messages from a single UDP [datagram].
  ///
  /// Invalid messages (bad CRC, too short) are silently skipped.
  static List<Gdl90Frame> extractMessages(Uint8List datagram) {
    final messages = <Gdl90Frame>[];
    int i = 0;

    while (i < datagram.length) {
      // Find start flag
      while (i < datagram.length && datagram[i] != _flagByte) {
        i++;
      }
      if (i >= datagram.length) break;
      i++; // skip start flag

      // Collect raw bytes until end flag
      final raw = <int>[];
      while (i < datagram.length && datagram[i] != _flagByte) {
        raw.add(datagram[i]);
        i++;
      }
      if (i < datagram.length) i++; // skip end flag

      // Need at least msgId (1) + FCS (2) = 3 bytes
      if (raw.length < 3) continue;

      // Byte unstuffing
      final unstuffed = _unstuff(raw);
      if (unstuffed.length < 3) continue;

      // CRC validation
      if (!Gdl90Crc.validate(unstuffed)) continue;

      // Extract message ID and payload (strip 2-byte FCS)
      final msgId = unstuffed[0];
      final payload =
          Uint8List.fromList(unstuffed.sublist(1, unstuffed.length - 2));
      messages.add(Gdl90Frame(messageId: msgId, payload: payload));
    }

    return messages;
  }

  /// Remove byte-stuffing escapes from raw frame data.
  static List<int> _unstuff(List<int> raw) {
    final result = <int>[];
    int j = 0;
    while (j < raw.length) {
      if (raw[j] == _escapeByte && j + 1 < raw.length) {
        result.add(raw[j + 1] ^ 0x20);
        j += 2;
      } else {
        result.add(raw[j]);
        j++;
      }
    }
    return result;
  }
}

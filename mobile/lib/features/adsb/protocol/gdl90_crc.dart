/// CRC-CCITT (polynomial 0x1021) as specified by GDL 90.
///
/// Uses a precomputed 256-entry lookup table for performance.
/// The FCS (Frame Check Sequence) is appended as two bytes (low then high)
/// after the message data and before the trailing flag byte.
class Gdl90Crc {
  Gdl90Crc._();

  static final List<int> _table = _buildTable();

  static List<int> _buildTable() {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = (i << 8) & 0xFFFF;
      for (int j = 0; j < 8; j++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
      table[i] = crc;
    }
    return table;
  }

  /// Compute CRC over [data] (message ID + payload, before FCS).
  static int compute(List<int> data) {
    int crc = 0;
    for (final byte in data) {
      crc = (_table[((crc >> 8) ^ byte) & 0xFF] ^ (crc << 8)) & 0xFFFF;
    }
    return crc;
  }

  /// Validate a complete unescaped message (ID + payload + 2-byte FCS).
  ///
  /// The FCS is stored low-byte first: `[..., fcsLo, fcsHi]`.
  /// Returns `true` if the CRC matches.
  static bool validate(List<int> messageWithFcs) {
    if (messageWithFcs.length < 3) return false;
    final fcsLo = messageWithFcs[messageWithFcs.length - 2];
    final fcsHi = messageWithFcs[messageWithFcs.length - 1];
    final expected = fcsLo | (fcsHi << 8);
    final payload = messageWithFcs.sublist(0, messageWithFcs.length - 2);
    return compute(payload) == expected;
  }
}

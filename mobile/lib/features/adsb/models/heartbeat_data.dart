/// Decoded GDL 90 Heartbeat message (0x00).
class HeartbeatData {
  /// Whether the GPS position is valid (status byte 1, bit 7).
  final bool gpsPositionValid;

  /// Whether the UAT receiver is initialized (status byte 1, bit 0).
  final bool uatInitialized;

  /// Whether the UTC time is valid (status byte 2, bit 0).
  final bool utcOk;

  /// Seconds since midnight UTC (17-bit, 0–86399).
  final int timestampSeconds;

  /// When this heartbeat was received locally.
  final DateTime receivedAt;

  const HeartbeatData({
    required this.gpsPositionValid,
    required this.uatInitialized,
    required this.utcOk,
    required this.timestampSeconds,
    required this.receivedAt,
  });

  HeartbeatData copyWith({
    bool? gpsPositionValid,
    bool? uatInitialized,
    bool? utcOk,
    int? timestampSeconds,
    DateTime? receivedAt,
  }) {
    return HeartbeatData(
      gpsPositionValid: gpsPositionValid ?? this.gpsPositionValid,
      uatInitialized: uatInitialized ?? this.uatInitialized,
      utcOk: utcOk ?? this.utcOk,
      timestampSeconds: timestampSeconds ?? this.timestampSeconds,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  @override
  String toString() =>
      'HeartbeatData(gps: $gpsPositionValid, uat: $uatInitialized, '
      'utc: $utcOk, ts: ${timestampSeconds}s)';
}

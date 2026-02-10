/// ADS-B receiver connection lifecycle states.
enum AdsbConnectionStatus {
  /// Scanning for receivers on the network.
  scanning,

  /// Found a receiver, attempting to connect.
  connecting,

  /// Actively receiving heartbeat messages.
  connected,

  /// No heartbeat received for 5+ seconds.
  stale,

  /// No heartbeat for 30+ seconds, or not connected.
  disconnected,
}

/// Aggregate ADS-B connection status for the UI status bar.
class AdsbStatus {
  final AdsbConnectionStatus status;
  final String? receiverName;
  final String? receiverIp;
  final bool gpsPositionValid;
  final int trafficCount;
  final DateTime? lastHeartbeat;
  final int messageCount;
  final int errorCount;

  const AdsbStatus({
    this.status = AdsbConnectionStatus.disconnected,
    this.receiverName,
    this.receiverIp,
    this.gpsPositionValid = false,
    this.trafficCount = 0,
    this.lastHeartbeat,
    this.messageCount = 0,
    this.errorCount = 0,
  });

  AdsbStatus copyWith({
    AdsbConnectionStatus? status,
    String? receiverName,
    String? receiverIp,
    bool? gpsPositionValid,
    int? trafficCount,
    DateTime? lastHeartbeat,
    int? messageCount,
    int? errorCount,
  }) {
    return AdsbStatus(
      status: status ?? this.status,
      receiverName: receiverName ?? this.receiverName,
      receiverIp: receiverIp ?? this.receiverIp,
      gpsPositionValid: gpsPositionValid ?? this.gpsPositionValid,
      trafficCount: trafficCount ?? this.trafficCount,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      messageCount: messageCount ?? this.messageCount,
      errorCount: errorCount ?? this.errorCount,
    );
  }

  @override
  String toString() => 'AdsbStatus($status, rx: $receiverName, '
      'msgs: $messageCount, tfc: $trafficCount)';
}

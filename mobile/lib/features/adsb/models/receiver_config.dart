import 'dart:convert';

/// Configuration for a known ADS-B receiver, persisted to SharedPreferences.
class ReceiverConfig {
  final String name;

  /// Manual IP address override. Null means auto-discover.
  final String? ipAddress;

  /// UDP port for GDL 90 data (default 4000).
  final int port;

  /// Device type identifier.
  final String deviceType;

  /// Serial number from GDL 90 Device ID message.
  final String? deviceSerial;

  /// Whether this is the user's preferred auto-connect receiver.
  final bool isPreferred;

  /// When the receiver was last successfully connected.
  final DateTime? lastConnected;

  const ReceiverConfig({
    required this.name,
    this.ipAddress,
    this.port = 4000,
    this.deviceType = 'generic',
    this.deviceSerial,
    this.isPreferred = false,
    this.lastConnected,
  });

  factory ReceiverConfig.fromJson(Map<String, dynamic> json) {
    return ReceiverConfig(
      name: json['name'] as String? ?? 'Unknown',
      ipAddress: json['ipAddress'] as String?,
      port: json['port'] as int? ?? 4000,
      deviceType: json['deviceType'] as String? ?? 'generic',
      deviceSerial: json['deviceSerial'] as String?,
      isPreferred: json['isPreferred'] as bool? ?? false,
      lastConnected: json['lastConnected'] != null
          ? DateTime.tryParse(json['lastConnected'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'deviceType': deviceType,
      'deviceSerial': deviceSerial,
      'isPreferred': isPreferred,
      'lastConnected': lastConnected?.toIso8601String(),
    };
  }

  ReceiverConfig copyWith({
    String? name,
    String? ipAddress,
    int? port,
    String? deviceType,
    String? deviceSerial,
    bool? isPreferred,
    DateTime? lastConnected,
  }) {
    return ReceiverConfig(
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      isPreferred: isPreferred ?? this.isPreferred,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  /// Serialize a list of receivers to JSON string for SharedPreferences.
  static String encodeList(List<ReceiverConfig> receivers) {
    return jsonEncode(receivers.map((r) => r.toJson()).toList());
  }

  /// Deserialize a list of receivers from SharedPreferences JSON string.
  static List<ReceiverConfig> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => ReceiverConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  String toString() => 'ReceiverConfig($name, $deviceType, ip: $ipAddress)';
}

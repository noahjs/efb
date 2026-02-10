import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A receiver discovered on the local network via ForeFlight discovery broadcast.
class DiscoveredReceiver {
  final String name;
  final String ipAddress;
  final int port;
  final DateTime discoveredAt;

  const DiscoveredReceiver({
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.discoveredAt,
  });

  @override
  String toString() => 'DiscoveredReceiver($name @ $ipAddress:$port)';
}

/// Listens on UDP port 63093 for ForeFlight-compatible discovery broadcasts.
///
/// ADS-B receivers that implement the ForeFlight discovery spec send periodic
/// JSON broadcasts like: `{"App":"Stratux","GDL90":{"port":4000}}`
///
/// This is supported by Stratux, ForeFlight Sentry, and other receivers.
class DiscoveryService {
  RawDatagramSocket? _socket;
  StreamSubscription? _subscription;
  final _discoveries = StreamController<DiscoveredReceiver>.broadcast();

  /// Stream of discovered receivers.
  Stream<DiscoveredReceiver> get discoveries => _discoveries.stream;

  /// Map of known receivers by IP address (for deduplication).
  final Map<String, DiscoveredReceiver> _known = {};

  /// All currently known receivers.
  Map<String, DiscoveredReceiver> get knownReceivers =>
      Map.unmodifiable(_known);

  /// Start listening for discovery broadcasts on UDP port 63093.
  Future<void> startListening() async {
    await stop();
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      63093,
    );
    _socket!.broadcastEnabled = true;
    _subscription = _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
          _parseDiscovery(datagram);
        }
      }
    });
  }

  void _parseDiscovery(Datagram datagram) {
    try {
      final json = jsonDecode(String.fromCharCodes(datagram.data));
      if (json is! Map<String, dynamic>) return;

      final name = json['App'] as String? ?? 'Unknown';
      final gdl90 = json['GDL90'] as Map<String, dynamic>?;
      final port = gdl90?['port'] as int? ?? 4000;
      final ip = datagram.address.address;

      final receiver = DiscoveredReceiver(
        name: name,
        ipAddress: ip,
        port: port,
        discoveredAt: DateTime.now(),
      );

      _known[ip] = receiver;
      _discoveries.add(receiver);
    } catch (_) {
      // Silently ignore non-JSON or malformed broadcasts.
    }
  }

  /// Stop listening for discovery broadcasts.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
  }

  /// Stop listening and release resources.
  void dispose() {
    stop();
    _discoveries.close();
  }
}

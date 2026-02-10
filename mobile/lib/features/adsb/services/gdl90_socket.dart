import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Manages a UDP socket for receiving GDL 90 data.
///
/// Binds to `0.0.0.0:<port>` (default 4000) to receive broadcast
/// UDP datagrams from ADS-B receivers on the local WiFi network.
/// Emits raw datagrams as a broadcast stream.
class Gdl90Socket {
  RawDatagramSocket? _socket;
  StreamSubscription? _subscription;
  final _dataController = StreamController<Uint8List>.broadcast();

  /// Stream of raw UDP datagram payloads.
  Stream<Uint8List> get dataStream => _dataController.stream;

  /// Whether the socket is currently bound and listening.
  bool get isOpen => _socket != null;

  /// Bind to all interfaces on [port] and start emitting datagrams.
  Future<void> open({int port = 4000}) async {
    await close();
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );
    _socket!.broadcastEnabled = true;
    _subscription = _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
          _dataController.add(Uint8List.fromList(datagram.data));
        }
      }
    });
  }

  /// Close the socket and stop listening.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
  }

  /// Close the socket and release the stream controller.
  void dispose() {
    close();
    _dataController.close();
  }
}

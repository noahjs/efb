import 'dart:async';
import 'dart:typed_data';

import '../protocol/gdl90_framing.dart';
import '../protocol/gdl90_messages.dart';
import '../protocol/heartbeat_decoder.dart';
import '../protocol/traffic_report_decoder.dart';
import '../protocol/ownship_geo_alt_decoder.dart';
import '../models/connection_state.dart';
import '../models/heartbeat_data.dart';
import 'gdl90_socket.dart';
import 'discovery_service.dart';

/// Orchestrates the GDL 90 connection lifecycle.
///
/// Manages the UDP socket, parses incoming messages, tracks connection
/// state via heartbeat watchdog, and dispatches decoded messages to
/// typed output streams.
///
/// Connection state machine:
/// ```
/// DISCONNECTED → CONNECTING → CONNECTED → STALE → DISCONNECTED
/// ```
///
/// Accepts [Gdl90Socket] and [DiscoveryService] via constructor for
/// testability (can inject mocks that emit controlled byte sequences).
class ConnectionManager {
  final Gdl90Socket _socket;
  final DiscoveryService _discovery;

  Timer? _heartbeatWatchdog;
  DateTime? _lastHeartbeat;
  bool _lastGpsValid = false;
  String? _receiverName;
  String? _receiverIp;
  int _messageCount = 0;
  int _errorCount = 0;

  // ── Output streams ──

  final _statusController = StreamController<AdsbStatus>.broadcast();
  final _ownshipController = StreamController<TrafficReportData>.broadcast();
  final _ownshipGeoAltController = StreamController<int>.broadcast();
  final _trafficController = StreamController<TrafficReportData>.broadcast();
  final _heartbeatController = StreamController<HeartbeatData>.broadcast();

  /// Connection status changes.
  Stream<AdsbStatus> get statusStream => _statusController.stream;

  /// Decoded ownship position reports (1 Hz).
  Stream<TrafficReportData> get ownshipStream => _ownshipController.stream;

  /// Decoded ownship geometric altitude (1 Hz).
  Stream<int> get ownshipGeoAltStream => _ownshipGeoAltController.stream;

  /// Decoded traffic reports (as received).
  Stream<TrafficReportData> get trafficStream => _trafficController.stream;

  /// Decoded heartbeat messages (1 Hz).
  Stream<HeartbeatData> get heartbeatStream => _heartbeatController.stream;

  AdsbConnectionStatus _state = AdsbConnectionStatus.disconnected;
  StreamSubscription? _dataSub;

  /// Current connection state.
  AdsbConnectionStatus get state => _state;

  ConnectionManager({
    Gdl90Socket? socket,
    DiscoveryService? discovery,
  })  : _socket = socket ?? Gdl90Socket(),
        _discovery = discovery ?? DiscoveryService();

  /// Open the GDL 90 UDP socket and start receiving data.
  ///
  /// Optionally specify [ipAddress] (unused for UDP broadcast mode)
  /// and [port] (default 4000).
  Future<void> connect({String? ipAddress, int port = 4000}) async {
    _receiverIp = ipAddress;
    _updateState(AdsbConnectionStatus.connecting);

    await _socket.open(port: port);
    _dataSub = _socket.dataStream.listen(_onDatagram);
    _startHeartbeatWatchdog();

    // Also start discovery listener
    await _discovery.startListening();
  }

  void _onDatagram(Uint8List datagram) {
    try {
      final frames = Gdl90Framing.extractMessages(datagram);
      for (final frame in frames) {
        _messageCount++;
        _dispatchMessage(frame);
      }
    } catch (_) {
      _errorCount++;
    }
  }

  void _dispatchMessage(Gdl90Frame frame) {
    switch (frame.messageId) {
      case Gdl90MessageId.heartbeat:
        final hb = HeartbeatDecoder.decode(frame.payload);
        if (hb != null) {
          _lastHeartbeat = DateTime.now();
          _lastGpsValid = hb.gpsPositionValid;
          _heartbeatController.add(hb);
          if (_state != AdsbConnectionStatus.connected) {
            _updateState(AdsbConnectionStatus.connected);
          }
        }
        break;

      case Gdl90MessageId.ownshipReport:
        final report = TrafficReportDecoder.decode(frame.payload);
        if (report != null) {
          _ownshipController.add(report);
        }
        break;

      case Gdl90MessageId.ownshipGeoAltitude:
        final alt = OwnshipGeoAltDecoder.decode(frame.payload);
        if (alt != null) {
          _ownshipGeoAltController.add(alt);
        }
        break;

      case Gdl90MessageId.trafficReport:
        final report = TrafficReportDecoder.decode(frame.payload);
        if (report != null) {
          _trafficController.add(report);
        }
        break;

      // Phase 2: ForeFlight extended (0x65) for AHRS + Device ID
      // Phase 2: Stratux extended (0xCC, 0x4C)
      default:
        break;
    }
  }

  void _startHeartbeatWatchdog() {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastHeartbeat == null) return;
      final age = DateTime.now().difference(_lastHeartbeat!);

      if (age.inSeconds >= 30 &&
          _state != AdsbConnectionStatus.disconnected) {
        _updateState(AdsbConnectionStatus.disconnected);
      } else if (age.inSeconds >= 5 &&
          _state == AdsbConnectionStatus.connected) {
        _updateState(AdsbConnectionStatus.stale);
      }
    });
  }

  void _updateState(AdsbConnectionStatus newState) {
    _state = newState;
    _statusController.add(AdsbStatus(
      status: newState,
      receiverName: _receiverName,
      receiverIp: _receiverIp,
      gpsPositionValid: _lastGpsValid,
      lastHeartbeat: _lastHeartbeat,
      messageCount: _messageCount,
      errorCount: _errorCount,
    ));
  }

  /// Set the receiver display name (e.g. from discovery or device ID).
  void setReceiverName(String name) {
    _receiverName = name;
  }

  /// Disconnect and stop all listeners.
  Future<void> disconnect() async {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = null;
    await _dataSub?.cancel();
    _dataSub = null;
    await _socket.close();
    await _discovery.stop();
    _lastHeartbeat = null;
    _lastGpsValid = false;
    _messageCount = 0;
    _errorCount = 0;
    _updateState(AdsbConnectionStatus.disconnected);
  }

  /// Disconnect and release all resources.
  void dispose() {
    disconnect();
    _statusController.close();
    _ownshipController.close();
    _ownshipGeoAltController.close();
    _trafficController.close();
    _heartbeatController.close();
    _socket.dispose();
    _discovery.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/robot_protocol.dart';
import 'robot_transport.dart';

/// TCP socket with auto-reconnect. Pair with [AsciiLineProtocol] (line
/// delimited) for simple microcontroller bridges.
class TcpTransport extends RobotTransport {
  TcpTransport({
    required this.host,
    required this.port,
    required super.protocol,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 2),
  });

  final String host;
  final int port;
  final bool autoReconnect;
  final Duration reconnectDelay;

  Socket? _socket;
  StreamSubscription? _sub;
  Timer? _retry;
  bool _wantConnected = false;

  @override
  Future<void> connect() async {
    _wantConnected = true;
    await _open();
  }

  Future<void> _open() async {
    _retry?.cancel();
    setStatus(LinkStatus.connecting);
    try {
      final s = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      s.setOption(SocketOption.tcpNoDelay, true);
      _socket = s;
      final Stream<Object> stream = protocol.lineDelimited
          ? s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())
          : s;
      _sub = stream.listen(
        handleIncoming,
        onError: (Object e) {
          lastError = e;
          _lost();
        },
        onDone: _lost,
      );
      setStatus(LinkStatus.connected);
      for (final m in protocol.handshake()) {
        send(m);
      }
    } catch (e) {
      lastError = e;
      _lost();
    }
  }

  void _lost() {
    _sub?.cancel();
    _sub = null;
    _socket?.destroy();
    _socket = null;
    if (!_wantConnected) {
      setStatus(LinkStatus.disconnected);
      return;
    }
    if (_retry?.isActive ?? false) return;
    if (autoReconnect) {
      setStatus(LinkStatus.connecting);
      _retry = Timer(reconnectDelay, _open);
    } else {
      setStatus(LinkStatus.failed);
    }
  }

  @override
  void send(Object data) {
    try {
      _socket?.add(asBytes(data));
    } catch (e) {
      lastError = e;
    }
  }

  @override
  Future<void> disconnect() async {
    _wantConnected = false;
    _retry?.cancel();
    await _sub?.cancel();
    _sub = null;
    _socket?.destroy();
    _socket = null;
    setStatus(LinkStatus.disconnected);
  }
}

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'robot_transport.dart';

/// WebSocket link with automatic reconnect. Works on every Flutter platform,
/// including web. Use with [JsonProtocol] or [RosbridgeProtocol].
class WebSocketTransport extends RobotTransport {
  WebSocketTransport({
    required this.uri,
    required super.protocol,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 2),
  });

  final Uri uri;
  final bool autoReconnect;
  final Duration reconnectDelay;

  WebSocketChannel? _channel;
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
      final ch = WebSocketChannel.connect(uri);
      await ch.ready;
      if (!_wantConnected) {
        await ch.sink.close();
        return;
      }
      _channel = ch;
      _sub = ch.stream.listen(
        (d) => handleIncoming(d as Object),
        onError: (Object e) {
          lastError = e;
          _lost();
        },
        onDone: _lost,
      );
      setStatus(LinkStatus.connected);
      for (final m in protocol.handshake()) {
        ch.sink.add(m);
      }
    } catch (e) {
      lastError = e;
      _lost();
    }
  }

  void _lost() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
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
  void send(Object data) => _channel?.sink.add(data);

  @override
  Future<void> disconnect() async {
    _wantConnected = false;
    _retry?.cancel();
    await _sub?.cancel();
    _sub = null;
    final ch = _channel;
    _channel = null;
    try {
      await ch?.sink.close();
    } catch (_) {}
    setStatus(LinkStatus.disconnected);
  }
}

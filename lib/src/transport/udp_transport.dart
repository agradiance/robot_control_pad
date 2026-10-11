import 'dart:async';
import 'dart:io';

import '../protocol/robot_protocol.dart';
import 'robot_transport.dart';

/// UDP datagrams to `host:port`. Lowest latency; best for ESP32/Arduino/
/// microcontroller robots on the same Wi-Fi. UDP is connectionless, so
/// "connected" means the socket is bound - rely on telemetry for link health.
class UdpTransport extends RobotTransport {
  UdpTransport({
    required this.host,
    required this.port,
    required super.protocol,
    this.localPort = 0,
  });

  final String host;
  final int port;
  final int localPort;

  RawDatagramSocket? _socket;
  InternetAddress? _remote;
  StreamSubscription? _sub;

  @override
  Future<void> connect() async {
    setStatus(LinkStatus.connecting);
    try {
      _remote = (await InternetAddress.lookup(host)).first;
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, localPort);
      _socket = socket;
      _sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        var dg = socket.receive();
        while (dg != null) {
          handleIncoming(dg.data);
          dg = socket.receive();
        }
      });
      setStatus(LinkStatus.connected);
      for (final m in protocol.handshake()) {
        send(m);
      }
    } catch (e) {
      lastError = e;
      setStatus(LinkStatus.failed);
    }
  }

  @override
  void send(Object data) {
    final s = _socket, r = _remote;
    if (s == null || r == null) return;
    s.send(asBytes(data), r, port);
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
    setStatus(LinkStatus.disconnected);
  }
}

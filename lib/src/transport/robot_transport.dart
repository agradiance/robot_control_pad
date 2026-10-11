import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/control_command.dart';
import '../core/telemetry.dart';
import '../protocol/robot_protocol.dart';

enum LinkStatus { disconnected, connecting, connected, failed }

/// Moves protocol messages over some physical link. Subclass this to add
/// Bluetooth, serial, MQTT, WebRTC... - the UI never needs to change.
abstract class RobotTransport {
  RobotTransport({required this.protocol});

  final RobotProtocol protocol;
  Object? lastError;

  final _statusCtl = StreamController<LinkStatus>.broadcast();
  final _telemetryCtl = StreamController<Telemetry>.broadcast();
  LinkStatus _status = LinkStatus.disconnected;

  LinkStatus get status => _status;
  Stream<LinkStatus> get statusStream => _statusCtl.stream;
  Stream<Telemetry> get telemetryStream => _telemetryCtl.stream;

  Future<void> connect();
  Future<void> disconnect();

  /// Raw send of an already-encoded message (`String` or `List<int>`).
  void send(Object data);

  void sendCommand(ControlCommand command) {
    if (_status == LinkStatus.connected) send(protocol.encodeCommand(command));
  }

  void sendEvent(String name, [Map<String, dynamic> data = const {}]) {
    if (_status != LinkStatus.connected) return;
    final msg = protocol.encodeEvent(name, data);
    if (msg != null) send(msg);
  }

  @protected
  void setStatus(LinkStatus s) {
    if (_status == s || _statusCtl.isClosed) return;
    _status = s;
    _statusCtl.add(s);
  }

  @protected
  void handleIncoming(Object data) {
    final t = protocol.decodeTelemetry(data);
    if (t != null) emitTelemetry(t);
  }

  @protected
  void emitTelemetry(Telemetry t) {
    if (!_telemetryCtl.isClosed) _telemetryCtl.add(t);
  }

  @mustCallSuper
  Future<void> dispose() async {
    await disconnect();
    await _statusCtl.close();
    await _telemetryCtl.close();
  }
}

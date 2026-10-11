import 'dart:async';
import 'dart:math' as math;

import '../core/control_command.dart';
import '../core/telemetry.dart';
import '../core/waypoint.dart';
import '../protocol/json_protocol.dart';
import 'robot_transport.dart';

enum MockRobotKind { ground, drone }

/// In-app robot simulator (unicycle / holonomic kinematics + simple drone
/// attitude and battery model). Lets you build and test a UI with no hardware.
/// Understands `goto`, `waypoints`, `cancel`, `takeoff`, `land` and `estop`.
class MockTransport extends RobotTransport {
  MockTransport({
    this.kind = MockRobotKind.ground,
    this.maxSpeed = 1.5,
    this.maxTurn = 2.0,
    this.maxClimb = 1.5,
  }) : super(protocol: const JsonProtocol());

  final MockRobotKind kind;
  final double maxSpeed, maxTurn, maxClimb;

  Timer? _timer;
  ControlCommand _cmd = ControlCommand.zero;
  double _x = 0, _y = 0, _th = 0, _alt = 0, _roll = 0, _pitch = 0, _battery = 100, _speed = 0;
  double? _altTarget;
  final List<Waypoint> _queue = [];
  int _tick = 0;

  @override
  Future<void> connect() async {
    setStatus(LinkStatus.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    setStatus(LinkStatus.connected);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _step(0.05));
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _cmd = ControlCommand.zero;
    setStatus(LinkStatus.disconnected);
  }

  @override
  void send(Object data) {}

  @override
  void sendCommand(ControlCommand command) {
    if (status == LinkStatus.connected) _cmd = command;
  }

  @override
  void sendEvent(String name, [Map<String, dynamic> data = const {}]) {
    switch (name) {
      case 'takeoff':
        if (kind == MockRobotKind.drone) _altTarget = 1.5;
        break;
      case 'land':
        if (kind == MockRobotKind.drone) _altTarget = 0;
        break;
      case 'goto':
        _queue
          ..clear()
          ..add(Waypoint((data['x'] as num).toDouble(), (data['y'] as num).toDouble()));
        break;
      case 'waypoints':
        _queue.clear();
        for (final p in (data['points'] as List).cast<Map>()) {
          _queue.add(Waypoint((p['x'] as num).toDouble(), (p['y'] as num).toDouble()));
        }
        break;
      case 'cancel':
      case 'estop':
        _queue.clear();
        _altTarget = null;
        _cmd = ControlCommand.zero;
        break;
    }
  }

  double _wrap(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  void _step(double dt) {
    var v = _cmd.surge * maxSpeed;
    var vy = _cmd.sway * maxSpeed;
    var w = _cmd.yaw * maxTurn;
    var vz = _cmd.heave * maxClimb;

    if (_queue.isNotEmpty && _cmd.isNeutral) {
      final t = _queue.first;
      final dx = t.x - _x, dy = t.y - _y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 0.15) {
        _queue.removeAt(0);
      } else {
        final err = _wrap(math.atan2(dy, dx) - _th);
        w = (err * 2).clamp(-maxTurn, maxTurn).toDouble();
        v = err.abs() < 0.6 ? math.min(maxSpeed * 0.6, dist) : 0.0;
        vy = 0;
      }
    }

    if (kind == MockRobotKind.drone) {
      if (_altTarget != null && vz == 0) {
        vz = (_altTarget! - _alt).clamp(-maxClimb, maxClimb).toDouble();
      }
      _alt = math.max(0, _alt + vz * dt);
      _pitch += (-_cmd.surge * 0.4 - _pitch) * 0.2;
      _roll += (-_cmd.sway * 0.4 - _roll) * 0.2;
    }

    _x += (v * math.cos(_th) - vy * math.sin(_th)) * dt;
    _y += (v * math.sin(_th) + vy * math.cos(_th)) * dt;
    _th = _wrap(_th + w * dt);
    _speed += (math.sqrt(v * v + vy * vy) - _speed) * 0.3;
    _battery = math.max(0, _battery - (0.02 + _speed * 0.03) * dt);

    if (++_tick % 2 != 0) return;
    final drone = kind == MockRobotKind.drone;
    emitTelemetry(Telemetry(
      batteryPercent: _battery,
      batteryVoltage: 10.5 + _battery * 0.021,
      pose: Pose2D(_x, _y, _th),
      speed: _speed,
      altitude: drone ? _alt : null,
      roll: drone ? _roll : null,
      pitch: drone ? _pitch : null,
      yaw: _th,
      linkQuality: 1,
      mode: drone ? (_alt > 0.05 ? 'FLYING' : 'GROUNDED') : (_queue.isNotEmpty ? 'AUTO' : 'MANUAL'),
    ));
  }
}

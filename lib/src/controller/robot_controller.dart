import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/control_command.dart';
import '../core/control_config.dart';
import '../core/input_shaping.dart';
import '../core/telemetry.dart';
import '../core/waypoint.dart';
import '../transport/robot_transport.dart';

/// Default input source name used by the built-in pads.
const String kPadSource = 'pad';

/// Central hub between input widgets and the robot link.
///
/// * Widgets push raw -1..1 values with [setAxis]/[setAxes] (several sources,
///   e.g. touch + keyboard, are summed and clamped).
/// * A fixed-rate timer shapes them (deadzone, expo, scale, slew), applies the
///   speed limit and arm/e-stop gates, and streams a [ControlCommand] - this
///   stream is also the heartbeat the robot should watch.
/// * Incoming telemetry is merged into [telemetry]; poses build [trail].
///
/// The controller owns the transport and disposes it.
class RobotController extends ChangeNotifier with WidgetsBindingObserver {
  RobotController({
    required this.transport,
    this.config = const ControlConfig(),
    this.maxTrailPoints = 2000,
  }) {
    _statusSub = transport.statusStream.listen(_onStatus);
    _telemetrySub = transport.telemetryStream.listen(_onTelemetry);
    _timer = Timer.periodic(config.sendInterval, (_) => _tick());
    WidgetsBinding.instance.addObserver(this);
  }

  final RobotTransport transport;
  final ControlConfig config;
  final int maxTrailPoints;

  /// Last shaped command that was streamed to the robot.
  final ValueNotifier<ControlCommand> command =
      ValueNotifier(ControlCommand.zero);

  final Map<String, Map<ControlAxis, double>> _inputs = {};
  final Map<String, bool> _buttons = {};
  final Map<ControlAxis, SlewLimiter> _slew = {
    for (final a in ControlAxis.values) a: SlewLimiter(),
  };

  StreamSubscription<LinkStatus>? _statusSub;
  StreamSubscription<Telemetry>? _telemetrySub;
  Timer? _timer;
  int _seq = 0;
  bool _armed = false;
  bool _estop = false;
  double _speedScale = 1.0;
  String _mode = 'manual';
  bool _disposed = false;

  Telemetry telemetry = const Telemetry();
  DateTime? lastTelemetryAt;
  final List<Pose2D> trail = [];
  final List<Waypoint> waypoints = [];

  // ---------------------------------------------------------------- state
  LinkStatus get linkStatus => transport.status;
  bool get isConnected => transport.status == LinkStatus.connected;
  bool get isArmed => _armed;
  bool get isEmergencyStopped => _estop;
  String get mode => _mode;
  double get speedScale => _speedScale;
  set speedScale(double v) {
    _speedScale = v.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  /// True if no telemetry arrived for [timeout].
  bool isTelemetryStale([Duration timeout = const Duration(seconds: 2)]) =>
      lastTelemetryAt == null ||
      DateTime.now().difference(lastTelemetryAt!) > timeout;

  // ----------------------------------------------------------- connection
  Future<void> connect() => transport.connect();
  Future<void> disconnect() => transport.disconnect();

  // --------------------------------------------------------------- inputs
  void setAxis(ControlAxis axis, double value, {String source = kPadSource}) {
    _inputs.putIfAbsent(source, () => {})[axis] = clampUnit(value);
  }

  void setAxes(Map<ControlAxis, double> values, {String source = kPadSource}) {
    final m = _inputs.putIfAbsent(source, () => {});
    values.forEach((a, v) => m[a] = clampUnit(v));
  }

  /// Zero everything one source (e.g. 'keyboard') contributed.
  void clearSource(String source) => _inputs.remove(source);

  void setButton(String id, bool pressed) {
    if (pressed) {
      _buttons[id] = true;
    } else {
      _buttons.remove(id);
    }
  }

  bool isPressed(String id) => _buttons[id] == true;

  void releaseAll() {
    _inputs.clear();
    _buttons.clear();
    for (final s in _slew.values) {
      s.reset();
    }
  }

  // ---------------------------------------------------- safety & vehicle
  void arm() {
    if (_estop) return;
    _armed = true;
    transport.sendEvent('arm');
    notifyListeners();
  }

  void disarm() {
    _armed = false;
    releaseAll();
    transport.sendEvent('disarm');
    notifyListeners();
  }

  /// Software e-stop: zero output now, block commands, tell the robot.
  /// Event is repeated so a single lost UDP packet cannot swallow it.
  /// NEVER rely on this alone - keep a hardware kill switch and a robot-side
  /// watchdog that stops the vehicle when commands stop arriving.
  void emergencyStop() {
    _estop = true;
    _armed = false;
    releaseAll();
    waypoints.clear();
    transport.sendCommand(ControlCommand.zero);
    for (var i = 0; i < 3; i++) {
      transport.sendEvent('estop');
    }
    notifyListeners();
  }

  void resetEmergencyStop() {
    if (!_estop) return;
    _estop = false;
    transport.sendEvent('estop_reset');
    notifyListeners();
  }

  void setMode(String mode) {
    _mode = mode;
    transport.sendEvent('mode', {'mode': mode});
    notifyListeners();
  }

  void sendEvent(String name, [Map<String, dynamic> data = const {}]) =>
      transport.sendEvent(name, data);

  void takeoff() => transport.sendEvent('takeoff');
  void land() => transport.sendEvent('land');
  void returnHome() => transport.sendEvent('rth');

  // ----------------------------------------------------------- navigation
  void addWaypoint(double x, double y, {double? theta}) {
    waypoints
        .add(Waypoint(x, y, theta: theta, label: '${waypoints.length + 1}'));
    notifyListeners();
  }

  void removeWaypoint(int index) {
    if (index < 0 || index >= waypoints.length) return;
    waypoints.removeAt(index);
    notifyListeners();
  }

  void clearWaypoints() {
    waypoints.clear();
    notifyListeners();
  }

  void startMission() {
    if (waypoints.isEmpty || _estop) return;
    transport.sendEvent(
        'waypoints', {'points': waypoints.map((w) => w.toJson()).toList()});
  }

  void goTo(Waypoint w) {
    if (_estop) return;
    transport.sendEvent('goto', w.toJson());
  }

  void cancelMission() => transport.sendEvent('cancel');

  // ------------------------------------------------------------- internals
  void _tick() {
    if (_disposed) return;
    final dt = config.sendInterval.inMicroseconds / 1e6;
    final blocked = _estop || (config.requireArm && !_armed);

    final values = <ControlAxis, double>{};
    for (final a in ControlAxis.values) {
      if (blocked) {
        _slew[a]!.reset();
        values[a] = 0;
        continue;
      }
      var raw = 0.0;
      for (final src in _inputs.values) {
        raw += src[a] ?? 0;
      }
      final cfg = config.axisConfig(a);
      final shaped = shapeAxis(clampUnit(raw), cfg) * _speedScale;
      values[a] = _slew[a]!.step(shaped, dt, cfg.slewRate);
    }

    final cmd = ControlCommand(
      surge: values[ControlAxis.surge]!,
      sway: values[ControlAxis.sway]!,
      heave: values[ControlAxis.heave]!,
      roll: values[ControlAxis.roll]!,
      pitch: values[ControlAxis.pitch]!,
      yaw: values[ControlAxis.yaw]!,
      buttons: blocked ? const {} : Map<String, bool>.of(_buttons),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sequence: _seq++ & 0x7fffffff,
    );
    command.value = cmd;
    transport.sendCommand(cmd);
  }

  void _onStatus(LinkStatus s) {
    if (s != LinkStatus.connected) {
      _armed = false;
      releaseAll();
    }
    notifyListeners();
  }

  void _onTelemetry(Telemetry t) {
    telemetry = telemetry.merge(t);
    lastTelemetryAt = DateTime.now();
    final p = t.pose;
    if (p != null) {
      final last = trail.isEmpty ? null : trail.last;
      if (last == null || (p.x - last.x).abs() + (p.y - last.y).abs() > 0.05) {
        trail.add(p);
        if (trail.length > maxTrailPoints) trail.removeAt(0);
      }
    }
    notifyListeners();
  }

  void clearTrail() {
    trail.clear();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && config.zeroOnBackground) {
      _armed = false;
      releaseAll();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _statusSub?.cancel();
    _telemetrySub?.cancel();
    command.dispose();
    transport.dispose();
    super.dispose();
  }
}

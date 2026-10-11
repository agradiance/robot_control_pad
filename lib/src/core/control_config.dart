import 'control_command.dart';

/// Per-axis shaping applied before commands leave the app.
class AxisConfig {
  const AxisConfig({
    this.deadzone = 0.05,
    this.expo = 0.0,
    this.scale = 1.0,
    this.invert = false,
    this.slewRate,
  });

  /// Inputs below this magnitude read as 0 (0..0.99).
  final double deadzone;

  /// 0 = linear, 1 = fully cubic (soft centre, aggressive ends).
  final double expo;

  /// Output multiplier (0..1) - a per-axis speed cap.
  final double scale;
  final bool invert;

  /// Max change in output per second (acceleration limit). `null` = off.
  final double? slewRate;
}

class ControlConfig {
  const ControlConfig({
    this.sendRateHz = 30,
    this.requireArm = false,
    this.zeroOnBackground = true,
    this.axes = const {},
    this.defaultAxis = const AxisConfig(),
  });

  /// Command stream rate. The stream doubles as a heartbeat: the robot should
  /// stop if commands stop arriving.
  final int sendRateHz;

  /// If true, outputs stay at zero until `controller.arm()` is called.
  final bool requireArm;

  /// Zero all inputs (and disarm) when the app leaves the foreground.
  final bool zeroOnBackground;

  final Map<ControlAxis, AxisConfig> axes;
  final AxisConfig defaultAxis;

  AxisConfig axisConfig(ControlAxis a) => axes[a] ?? defaultAxis;
  Duration get sendInterval => Duration(microseconds: (1e6 / sendRateHz).round());
}

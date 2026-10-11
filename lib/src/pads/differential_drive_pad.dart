import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../core/control_command.dart';
import '../widgets/axis_slider.dart';
import '../widgets/safety_widgets.dart';
import '../widgets/virtual_joystick.dart';
import 'pad_layout.dart';

enum DriveStyle {
  /// One stick: up/down = forward/back, left/right = turn.
  arcade,

  /// Left stick = forward/back, right stick = turn.
  twinStick,

  /// Left stick = left track, right stick = right track.
  tank,
}

/// Pad for differential / skid-steer / tracked mobile robots.
/// Outputs `surge` and `yaw`.
class DifferentialDrivePad extends StatefulWidget {
  const DifferentialDrivePad({
    super.key,
    required this.controller,
    this.style = DriveStyle.arcade,
    this.stickSize = 190,
  });

  final RobotController controller;
  final DriveStyle style;
  final double stickSize;

  @override
  State<DifferentialDrivePad> createState() => _DifferentialDrivePadState();
}

class _DifferentialDrivePadState extends State<DifferentialDrivePad> {
  double _l = 0, _r = 0;

  RobotController get c => widget.controller;

  void _tank() => c.setAxes({ControlAxis.surge: (_l + _r) / 2, ControlAxis.yaw: (_r - _l) / 2});

  @override
  void dispose() {
    c.clearSource(kPadSource);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stickSize;
    late final Widget left, right;
    switch (widget.style) {
      case DriveStyle.arcade:
        left = VirtualJoystick(size: s, onChanged: (v) => c.setAxes({ControlAxis.surge: v.dy, ControlAxis.yaw: -v.dx}));
        right = _speed();
        break;
      case DriveStyle.twinStick:
        left = VirtualJoystick(
            size: s, lock: JoystickAxisLock.vertical, onChanged: (v) => c.setAxis(ControlAxis.surge, v.dy));
        right = VirtualJoystick(
            size: s, lock: JoystickAxisLock.horizontal, onChanged: (v) => c.setAxis(ControlAxis.yaw, -v.dx));
        break;
      case DriveStyle.tank:
        left = VirtualJoystick(
            size: s, lock: JoystickAxisLock.vertical, onChanged: (v) { _l = v.dy; _tank(); });
        right = VirtualJoystick(
            size: s, lock: JoystickAxisLock.vertical, onChanged: (v) { _r = v.dy; _tank(); });
        break;
    }
    return PadLayout(
      controller: c,
      left: left,
      right: right,
      center: Column(mainAxisSize: MainAxisSize.min, children: [
        if (c.config.requireArm) ...[ArmSlider(controller: c), const SizedBox(height: 12)],
        EmergencyStopButton(controller: c),
        if (widget.style != DriveStyle.arcade) ...[const SizedBox(height: 12), _speed(horizontal: true)],
      ]),
    );
  }

  Widget _speed({bool horizontal = false}) => AxisSlider(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        length: horizontal ? 180 : 190,
        thickness: 48,
        initialValue: c.speedScale,
        label: 'SPEED LIMIT',
        onChanged: (v) => c.speedScale = v < 0.1 ? 0.1 : v,
      );
}

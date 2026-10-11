import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../core/control_command.dart';
import '../widgets/axis_slider.dart';
import '../widgets/safety_widgets.dart';
import '../widgets/virtual_joystick.dart';
import 'pad_layout.dart';

/// Holonomic / mecanum / omni-wheel pad: left stick translates (`surge` +
/// `sway`), right stick rotates (`yaw`).
class OmniDrivePad extends StatefulWidget {
  const OmniDrivePad({super.key, required this.controller, this.stickSize = 190});

  final RobotController controller;
  final double stickSize;

  @override
  State<OmniDrivePad> createState() => _OmniDrivePadState();
}

class _OmniDrivePadState extends State<OmniDrivePad> {
  RobotController get c => widget.controller;

  @override
  void dispose() {
    c.clearSource(kPadSource);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PadLayout(
      controller: c,
      left: VirtualJoystick(
        size: widget.stickSize,
        onChanged: (v) => c.setAxes({ControlAxis.surge: v.dy, ControlAxis.sway: -v.dx}),
      ),
      right: VirtualJoystick(
        size: widget.stickSize,
        lock: JoystickAxisLock.horizontal,
        onChanged: (v) => c.setAxis(ControlAxis.yaw, -v.dx),
      ),
      center: Column(mainAxisSize: MainAxisSize.min, children: [
        if (c.config.requireArm) ...[ArmSlider(controller: c), const SizedBox(height: 12)],
        EmergencyStopButton(controller: c),
        const SizedBox(height: 12),
        AxisSlider(
          direction: Axis.horizontal,
          length: 180,
          thickness: 44,
          initialValue: c.speedScale,
          label: 'SPEED LIMIT',
          onChanged: (v) => c.speedScale = v < 0.1 ? 0.1 : v,
        ),
      ]),
    );
  }
}

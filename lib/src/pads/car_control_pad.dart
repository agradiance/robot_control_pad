import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../core/control_command.dart';
import '../widgets/axis_slider.dart';
import '../widgets/safety_widgets.dart';
import '../widgets/steering_wheel.dart';
import 'pad_layout.dart';

/// Steering wheel + gas/brake pedals + D/R gear for car-like (Ackermann) robots.
///
/// Outputs `surge` (gas, negated in reverse, zero while braking) and `yaw`
/// carrying the normalised steering command (+1 = full left). Map it to your
/// steering servo angle on the robot side. The `brake` button is also set in
/// `ControlCommand.buttons`.
class CarControlPad extends StatefulWidget {
  const CarControlPad({super.key, required this.controller, this.wheelSize = 230});

  final RobotController controller;
  final double wheelSize;

  @override
  State<CarControlPad> createState() => _CarControlPadState();
}

class _CarControlPadState extends State<CarControlPad> {
  double _wheel = 0, _gas = 0, _brake = 0;
  bool _reverse = false;

  RobotController get c => widget.controller;

  void _push() {
    final braking = _brake > 0.05;
    c.setAxes({
      ControlAxis.surge: braking ? 0 : (_reverse ? -_gas : _gas),
      ControlAxis.yaw: -_wheel,
    });
    c.setButton('brake', braking);
  }

  @override
  void dispose() {
    c.clearSource(kPadSource);
    c.setButton('brake', false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PadLayout(
      controller: c,
      left: SteeringWheel(size: widget.wheelSize, onChanged: (v) { _wheel = v; _push(); }),
      right: Row(mainAxisSize: MainAxisSize.min, children: [
        AxisSlider(
          springBack: true,
          length: 190,
          thickness: 60,
          color: const Color(0xFFE53935),
          label: 'BRAKE',
          onChanged: (v) { _brake = v; _push(); },
        ),
        const SizedBox(width: 16),
        AxisSlider(
          springBack: true,
          length: 190,
          thickness: 60,
          color: const Color(0xFF43A047),
          label: 'GAS',
          onChanged: (v) { _gas = v; _push(); },
        ),
      ]),
      center: Column(mainAxisSize: MainAxisSize.min, children: [
        if (c.config.requireArm) ...[ArmSlider(controller: c), const SizedBox(height: 12)],
        EmergencyStopButton(controller: c),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('D')),
            ButtonSegment(value: true, label: Text('R')),
          ],
          selected: {_reverse},
          onSelectionChanged: (s) {
            setState(() => _reverse = s.first);
            _push();
          },
        ),
      ]),
    );
  }
}

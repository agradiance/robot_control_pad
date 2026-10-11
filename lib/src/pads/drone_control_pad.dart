import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../core/control_command.dart';
import '../widgets/instruments.dart';
import '../widgets/safety_widgets.dart';
import '../widgets/virtual_joystick.dart';
import 'pad_layout.dart';

enum DroneStickMode {
  /// Left: forward/back + yaw. Right: climb/descend + sideways.
  mode1,

  /// Left: climb/descend + yaw. Right: forward/back + sideways.
  mode2,
}

/// Two-stick RC-style pad for multirotors / VTOL (velocity commands):
/// `surge`, `sway`, `heave`, `yaw`. Includes arm slider, e-stop (kill),
/// takeoff / land / return-home events, artificial horizon and compass.
class DroneControlPad extends StatefulWidget {
  const DroneControlPad({
    super.key,
    required this.controller,
    this.stickMode = DroneStickMode.mode2,
    this.stickSize = 190,
    this.showInstruments = true,
  });

  final RobotController controller;
  final DroneStickMode stickMode;
  final double stickSize;
  final bool showInstruments;

  @override
  State<DroneControlPad> createState() => _DroneControlPadState();
}

class _DroneControlPadState extends State<DroneControlPad> {
  RobotController get c => widget.controller;
  bool get _m2 => widget.stickMode == DroneStickMode.mode2;

  @override
  void dispose() {
    c.clearSource(kPadSource);
    super.dispose();
  }

  void _left(Offset v) => c.setAxes(_m2
      ? {ControlAxis.heave: v.dy, ControlAxis.yaw: -v.dx}
      : {ControlAxis.surge: v.dy, ControlAxis.yaw: -v.dx});

  void _right(Offset v) => c.setAxes(_m2
      ? {ControlAxis.surge: v.dy, ControlAxis.sway: -v.dx}
      : {ControlAxis.heave: v.dy, ControlAxis.sway: -v.dx});

  @override
  Widget build(BuildContext context) {
    return PadLayout(
      controller: c,
      left: VirtualJoystick(size: widget.stickSize, onChanged: _left),
      right: VirtualJoystick(size: widget.stickSize, onChanged: _right),
      center: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.showInstruments)
          ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final t = c.telemetry;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                AttitudeIndicator(roll: t.roll ?? 0, pitch: t.pitch ?? 0, size: 110),
                const SizedBox(width: 12),
                HeadingIndicator(headingDegrees: t.headingDegrees ?? 0, size: 90),
              ]);
            },
          ),
        const SizedBox(height: 10),
        ArmSlider(controller: c),
        const SizedBox(height: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.tonal(onPressed: c.takeoff, child: const Text('TAKEOFF')),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: c.land, child: const Text('LAND')),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: c.returnHome, child: const Text('RTH')),
          const SizedBox(width: 12),
          EmergencyStopButton(controller: c, size: 64),
        ]),
      ]),
    );
  }
}

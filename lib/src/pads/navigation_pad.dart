import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../core/control_command.dart';
import '../core/waypoint.dart';
import '../widgets/navigation_map.dart';
import '../widgets/safety_widgets.dart';
import '../widgets/telemetry_widgets.dart';
import '../widgets/virtual_joystick.dart';

/// Full-screen map with overlay telemetry, e-stop and a small manual-override
/// stick. Tap the map to add waypoints, then press play to run the mission.
class NavigationPad extends StatefulWidget {
  const NavigationPad({
    super.key,
    required this.controller,
    this.tapMode = MapTapMode.addWaypoint,
    this.grid,
    this.stickSize = 150,
  });

  final RobotController controller;
  final MapTapMode tapMode;
  final OccupancyGridData? grid;
  final double stickSize;

  @override
  State<NavigationPad> createState() => _NavigationPadState();
}

class _NavigationPadState extends State<NavigationPad> {
  RobotController get c => widget.controller;

  @override
  void dispose() {
    c.clearSource(kPadSource);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: NavigationMap(controller: c, tapMode: widget.tapMode, grid: widget.grid)),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Align(alignment: Alignment.topLeft, child: TelemetryBar(controller: c)),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              VirtualJoystick(
                size: widget.stickSize,
                onChanged: (v) => c.setAxes({ControlAxis.surge: v.dy, ControlAxis.yaw: -v.dx}),
              ),
              const Spacer(),
              EmergencyStopButton(controller: c),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

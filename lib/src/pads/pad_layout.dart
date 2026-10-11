import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../widgets/telemetry_widgets.dart';

/// Shared frame for the ready-made pads: telemetry strip on top, [left] and
/// [right] controls anchored to the bottom corners, [center] in between.
class PadLayout extends StatelessWidget {
  const PadLayout({
    super.key,
    required this.controller,
    this.left,
    this.right,
    this.center,
    this.top,
    this.padding = const EdgeInsets.all(16),
  });

  final RobotController controller;
  final Widget? left, right, center, top;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: padding,
        child: Column(children: [
          top ?? TelemetryBar(controller: controller),
          const SizedBox(height: 8),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (left != null) left!,
              Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: center ?? const SizedBox()))),
              if (right != null) right!,
            ]),
          ),
        ]),
      ),
    );
  }
}

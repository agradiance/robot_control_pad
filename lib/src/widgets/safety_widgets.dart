import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../controller/robot_controller.dart';
import 'common.dart';

/// Big red software e-stop. Triggers instantly on touch-down. While stopped
/// it turns into a "HOLD TO RESET" button (long-press) to avoid accidental
/// re-enable.
class EmergencyStopButton extends StatelessWidget {
  const EmergencyStopButton({super.key, required this.controller, this.size = 84});

  final RobotController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stopped = controller.isEmergencyStopped;
        return Listener(
          onPointerDown: (_) {
            if (!stopped) {
              HapticFeedback.heavyImpact();
              controller.emergencyStop();
            }
          },
          child: GestureDetector(
            onLongPress: stopped ? controller.resetEmergencyStop : null,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stopped ? const Color(0xFF5A1010) : const Color(0xFFD32F2F),
                border: Border.all(color: const Color(0xFFFFCDD2), width: 4),
                boxShadow: stopped ? null : const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
              ),
              child: Text(
                stopped ? 'HOLD TO\nRESET' : 'STOP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: stopped ? size * 0.13 : size * 0.24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Slide to arm" control; tap while armed to disarm.
class ArmSlider extends StatefulWidget {
  const ArmSlider({super.key, required this.controller, this.width = 220, this.height = 52});

  final RobotController controller;
  final double width, height;

  @override
  State<ArmSlider> createState() => _ArmSliderState();
}

class _ArmSliderState extends State<ArmSlider> {
  double _drag = 0;

  void _update(double dx) {
    final usable = widget.width - widget.height;
    setState(() => _drag = clampDouble((dx - widget.height / 2) / usable, 0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.isEmergencyStopped) {
          return _pill(const Color(0xFF5A1010), 'E-STOP ACTIVE');
        }
        if (c.isArmed) {
          return GestureDetector(
            onTap: c.disarm,
            child: _pill(const Color(0xFF2E7D32), 'ARMED - tap to disarm'),
          );
        }
        final thumb = widget.height - 8;
        return GestureDetector(
          onHorizontalDragStart: (d) => _update(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => _update(d.localPosition.dx),
          onHorizontalDragEnd: (_) {
            if (_drag > 0.95) {
              HapticFeedback.mediumImpact();
              c.arm();
            }
            setState(() => _drag = 0);
          },
          onHorizontalDragCancel: () => setState(() => _drag = 0),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: alpha(cs.onSurface, 0.12),
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(color: alpha(cs.onSurface, 0.35), width: 2),
            ),
            child: Stack(alignment: Alignment.centerLeft, children: [
              Center(child: Text('SLIDE TO ARM', style: Theme.of(context).textTheme.labelLarge)),
              Positioned(
                left: 4 + _drag * (widget.width - widget.height),
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
                  child: Icon(Icons.chevron_right, color: cs.onPrimary),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _pill(Color color, String text) => Container(
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(widget.height / 2)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
}

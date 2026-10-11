import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../controller/robot_controller.dart';
import '../core/control_command.dart';

class KeyAxis {
  const KeyAxis(this.axis, this.value);
  final ControlAxis axis;
  final double value;
}

class KeyboardMapping {
  KeyboardMapping({
    required this.axes,
    this.emergencyStop = LogicalKeyboardKey.space,
    this.resetEmergencyStop = LogicalKeyboardKey.keyX,
    this.toggleArm = LogicalKeyboardKey.enter,
  });

  final Map<LogicalKeyboardKey, KeyAxis> axes;
  final LogicalKeyboardKey emergencyStop, resetEmergencyStop, toggleArm;

  /// W/S forward-back, A/D turn, Q/E strafe, R/F up-down (arrow keys mirror W/S/A/D).
  static KeyboardMapping wasd() => KeyboardMapping(axes: {
        LogicalKeyboardKey.keyW: const KeyAxis(ControlAxis.surge, 1),
        LogicalKeyboardKey.arrowUp: const KeyAxis(ControlAxis.surge, 1),
        LogicalKeyboardKey.keyS: const KeyAxis(ControlAxis.surge, -1),
        LogicalKeyboardKey.arrowDown: const KeyAxis(ControlAxis.surge, -1),
        LogicalKeyboardKey.keyA: const KeyAxis(ControlAxis.yaw, 1),
        LogicalKeyboardKey.arrowLeft: const KeyAxis(ControlAxis.yaw, 1),
        LogicalKeyboardKey.keyD: const KeyAxis(ControlAxis.yaw, -1),
        LogicalKeyboardKey.arrowRight: const KeyAxis(ControlAxis.yaw, -1),
        LogicalKeyboardKey.keyQ: const KeyAxis(ControlAxis.sway, 1),
        LogicalKeyboardKey.keyE: const KeyAxis(ControlAxis.sway, -1),
        LogicalKeyboardKey.keyR: const KeyAxis(ControlAxis.heave, 1),
        LogicalKeyboardKey.keyF: const KeyAxis(ControlAxis.heave, -1),
      });
}

/// Keyboard teleop for desktop / web / Chromebook. Wrap any pad:
///
/// ```dart
/// KeyboardControlInput(controller: c, child: DifferentialDrivePad(controller: c))
/// ```
/// Space = e-stop, X = reset e-stop, Enter = toggle arm. Losing focus releases all keys.
class KeyboardControlInput extends StatefulWidget {
  KeyboardControlInput({
    super.key,
    required this.controller,
    required this.child,
    KeyboardMapping? mapping,
    this.autofocus = true,
  }) : mapping = mapping ?? KeyboardMapping.wasd();

  final RobotController controller;
  final Widget child;
  final KeyboardMapping mapping;
  final bool autofocus;

  @override
  State<KeyboardControlInput> createState() => _KeyboardControlInputState();
}

class _KeyboardControlInputState extends State<KeyboardControlInput> {
  static const _source = 'keyboard';
  final Set<LogicalKeyboardKey> _pressed = {};

  RobotController get c => widget.controller;

  void _push() {
    final sums = {for (final a in ControlAxis.values) a: 0.0};
    for (final k in _pressed) {
      final b = widget.mapping.axes[k];
      if (b != null) sums[b.axis] = sums[b.axis]! + b.value;
    }
    c.setAxes(sums, source: _source);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final m = widget.mapping;
    final key = e.logicalKey;
    if (e is KeyDownEvent) {
      if (key == m.emergencyStop) {
        c.emergencyStop();
        return KeyEventResult.handled;
      }
      if (key == m.resetEmergencyStop) {
        c.resetEmergencyStop();
        return KeyEventResult.handled;
      }
      if (key == m.toggleArm) {
        c.isArmed ? c.disarm() : c.arm();
        return KeyEventResult.handled;
      }
    }
    if (!m.axes.containsKey(key)) return KeyEventResult.ignored;
    if (e is KeyDownEvent) {
      _pressed.add(key);
    } else if (e is KeyUpEvent) {
      _pressed.remove(key);
    }
    _push();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    c.clearSource(_source);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        onFocusChange: (focused) {
          if (!focused) {
            _pressed.clear();
            c.clearSource(_source);
          }
        },
        child: widget.child,
      );
}

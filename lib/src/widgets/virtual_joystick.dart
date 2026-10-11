import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/input_shaping.dart';
import 'common.dart';

enum JoystickAxisLock { none, horizontal, vertical }

/// Multi-touch safe virtual joystick. Emits a normalised offset where
/// dx: +right, dy: +UP, both in -1..1 (circular or square travel).
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.onChanged,
    this.onRelease,
    this.size = 180,
    this.springBack = true,
    this.lock = JoystickAxisLock.none,
    this.square = false,
    this.visualDeadzone = 0,
    this.haptics = true,
    this.color,
  });

  final ValueChanged<Offset> onChanged;
  final VoidCallback? onRelease;
  final double size;

  /// Return to centre on release. Set false for "hold position" sticks.
  final bool springBack;
  final JoystickAxisLock lock;
  final bool square;

  /// Draws a deadzone ring (0..1) - purely visual.
  final double visualDeadzone;
  final bool haptics;
  final Color? color;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _value = Offset.zero;
  int? _pointer;

  double get _knobR => widget.size * 0.2;
  double get _travel => widget.size / 2 - _knobR;

  void _update(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    var d = (local - c) / _travel;
    if (widget.lock == JoystickAxisLock.horizontal) d = Offset(d.dx, 0);
    if (widget.lock == JoystickAxisLock.vertical) d = Offset(0, d.dy);
    if (widget.square) {
      d = Offset(clampUnit(d.dx), clampUnit(d.dy));
    } else if (d.distance > 1) {
      d = d / d.distance;
    }
    final v = Offset(d.dx, -d.dy);
    if (v != _value) {
      setState(() => _value = v);
      widget.onChanged(v);
    }
  }

  void _release() {
    _pointer = null;
    if (widget.springBack) {
      setState(() => _value = Offset.zero);
      widget.onChanged(Offset.zero);
    } else {
      setState(() {});
    }
    widget.onRelease?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: widget.size,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          if (widget.haptics) HapticFeedback.lightImpact();
          _update(e.localPosition);
        },
        onPointerMove: (e) {
          if (e.pointer == _pointer) _update(e.localPosition);
        },
        onPointerUp: (e) {
          if (e.pointer == _pointer) _release();
        },
        onPointerCancel: (e) {
          if (e.pointer == _pointer) _release();
        },
        child: CustomPaint(
          painter: _JoystickPainter(
            value: _value,
            active: _pointer != null,
            base: cs.onSurface,
            accent: widget.color ?? cs.primary,
            square: widget.square,
            knobRadius: _knobR,
            deadzone: widget.visualDeadzone,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.value,
    required this.active,
    required this.base,
    required this.accent,
    required this.square,
    required this.knobRadius,
    required this.deadzone,
  });

  final Offset value;
  final bool active, square;
  final Color base, accent;
  final double knobRadius, deadzone;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final travel = r - knobRadius;
    final fill = Paint()..color = alpha(base, 0.10);
    final line = Paint()
      ..color = alpha(base, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (square) {
      final rr = RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r), Radius.circular(r * 0.2));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, line);
    } else {
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r - 1, line);
    }
    final thin = Paint()
      ..color = alpha(base, 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(c - Offset(travel, 0), c + Offset(travel, 0), thin);
    canvas.drawLine(c - Offset(0, travel), c + Offset(0, travel), thin);
    canvas.drawCircle(c, travel * 0.5, Paint()..color = alpha(base, 0.15)..style = PaintingStyle.stroke);
    if (deadzone > 0) {
      canvas.drawCircle(
          c, travel * deadzone, Paint()..color = alpha(accent, 0.4)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    final kp = c + Offset(value.dx, -value.dy) * travel;
    canvas.drawLine(c, kp, Paint()..color = alpha(accent, 0.45)..strokeWidth = 4..strokeCap = StrokeCap.round);
    canvas.drawCircle(kp, knobRadius, Paint()..color = active ? accent : alpha(accent, 0.75));
    canvas.drawCircle(
        kp, knobRadius, Paint()..color = alpha(const Color(0xFFFFFFFF), 0.4)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_JoystickPainter o) =>
      o.value != value || o.active != active || o.accent != accent || o.base != base;
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart';

import 'common.dart';

/// Rotating steering wheel. Emits -1 (full left) .. +1 (full right), where
/// +1 = clockwise. Springs back to centre on release.
class SteeringWheel extends StatefulWidget {
  const SteeringWheel({
    super.key,
    required this.onChanged,
    this.size = 220,
    this.maxAngle = math.pi * 0.75,
    this.springBack = true,
    this.color,
  });

  final ValueChanged<double> onChanged;
  final double size;

  /// Lock-to-lock half range in radians.
  final double maxAngle;
  final bool springBack;
  final Color? color;

  @override
  State<SteeringWheel> createState() => _SteeringWheelState();
}

class _SteeringWheelState extends State<SteeringWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  double _angle = 0, _from = 0, _lastTouch = 0;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))
      ..addListener(() {
        setState(() => _angle = _from * (1 - Curves.easeOut.transform(_ctl.value)));
        widget.onChanged(_angle / widget.maxAngle);
      });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  double _touchAngle(Offset p) {
    final c = Offset(widget.size / 2, widget.size / 2);
    return math.atan2(p.dy - c.dy, p.dx - c.dx);
  }

  double _norm(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
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
          _ctl.stop();
          _lastTouch = _touchAngle(e.localPosition);
        },
        onPointerMove: (e) {
          if (e.pointer != _pointer) return;
          final a = _touchAngle(e.localPosition);
          final next = clampDouble(_angle + _norm(a - _lastTouch), -widget.maxAngle, widget.maxAngle);
          _lastTouch = a;
          if (next != _angle) {
            setState(() => _angle = next);
            widget.onChanged(_angle / widget.maxAngle);
          }
        },
        onPointerUp: (e) {
          if (e.pointer == _pointer) _release();
        },
        onPointerCancel: (e) {
          if (e.pointer == _pointer) _release();
        },
        child: Transform.rotate(
          angle: _angle,
          child: CustomPaint(painter: _WheelPainter(cs.onSurface, widget.color ?? cs.primary)),
        ),
      ),
    );
  }

  void _release() {
    _pointer = null;
    if (widget.springBack && _angle != 0) {
      _from = _angle;
      _ctl.forward(from: 0);
    }
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.base, this.accent);
  final Color base, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..color = alpha(base, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16;
    canvas.drawCircle(c, r * 0.88, ring);
    final spoke = Paint()
      ..color = alpha(base, 0.55)
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + Offset(-r * 0.8, 0), spoke);
    canvas.drawLine(c, c + Offset(r * 0.8, 0), spoke);
    canvas.drawLine(c, c + Offset(0, r * 0.8), spoke);
    canvas.drawCircle(c, r * 0.22, Paint()..color = alpha(accent, 0.85));
    canvas.drawLine(
      c + Offset(0, -r * 0.96),
      c + Offset(0, -r * 0.76),
      Paint()..color = accent..strokeWidth = r * 0.1..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter o) => o.accent != accent || o.base != base;
}

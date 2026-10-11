import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'common.dart';

/// Digital 4 or 8-way pad. Emits dx: +right, dy: +UP in {-1, 0, 1}
/// (diagonals scaled by 0.7071 when [normalizeDiagonals]).
class DPad extends StatefulWidget {
  const DPad({
    super.key,
    required this.onChanged,
    this.size = 170,
    this.eightWay = false,
    this.normalizeDiagonals = true,
    this.haptics = true,
    this.color,
  });

  final ValueChanged<Offset> onChanged;
  final double size;
  final bool eightWay, normalizeDiagonals, haptics;
  final Color? color;

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  Offset _value = Offset.zero;
  int? _pointer;

  static const _dirs8 = [
    Offset(1, 0), Offset(1, 1), Offset(0, 1), Offset(-1, 1),
    Offset(-1, 0), Offset(-1, -1), Offset(0, -1), Offset(1, -1),
  ];

  void _update(Offset local) {
    final d = local - Offset(widget.size / 2, widget.size / 2);
    Offset v = Offset.zero;
    if (d.distance > widget.size * 0.12) {
      if (widget.eightWay) {
        final a = math.atan2(-d.dy, d.dx);
        final i = ((a + math.pi / 8) / (math.pi / 4)).floor() % 8;
        v = _dirs8[i];
        if (widget.normalizeDiagonals && v.dx != 0 && v.dy != 0) v = v * 0.70710678;
      } else if (d.dx.abs() > d.dy.abs()) {
        v = Offset(d.dx.sign, 0);
      } else {
        v = Offset(0, -d.dy.sign);
      }
    }
    if (v != _value) {
      if (widget.haptics && v != Offset.zero) HapticFeedback.selectionClick();
      setState(() => _value = v);
      widget.onChanged(v);
    }
  }

  void _release() {
    _pointer = null;
    setState(() => _value = Offset.zero);
    widget.onChanged(Offset.zero);
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
        child: CustomPaint(painter: _DPadPainter(_value, cs.onSurface, widget.color ?? cs.primary)),
      ),
    );
  }
}

class _DPadPainter extends CustomPainter {
  _DPadPainter(this.v, this.base, this.accent);
  final Offset v;
  final Color base, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final a = size.width;
    final armW = a * 0.34;
    final armL = a * 0.4;

    void arm(Offset dir, bool on) {
      final center = c + Offset(dir.dx, -dir.dy) * (a * 0.3);
      final horizontal = dir.dx != 0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: horizontal ? armL : armW, height: horizontal ? armW : armL),
        Radius.circular(a * 0.07),
      );
      canvas.drawRRect(rect, Paint()..color = on ? accent : alpha(base, 0.14));
      canvas.drawRRect(rect, Paint()..color = alpha(base, 0.35)..style = PaintingStyle.stroke..strokeWidth = 2);
      final s = a * 0.07;
      final d = Offset(dir.dx, -dir.dy);
      final p = c + d * (a * 0.34);
      final perp = Offset(-d.dy, d.dx);
      final tri = Path()
        ..moveTo(p.dx + d.dx * s, p.dy + d.dy * s)
        ..lineTo(p.dx - d.dx * s + perp.dx * s, p.dy - d.dy * s + perp.dy * s)
        ..lineTo(p.dx - d.dx * s - perp.dx * s, p.dy - d.dy * s - perp.dy * s)
        ..close();
      canvas.drawPath(tri, Paint()..color = on ? const Color(0xFFFFFFFF) : alpha(base, 0.6));
    }

    arm(const Offset(0, 1), v.dy > 0);
    arm(const Offset(0, -1), v.dy < 0);
    arm(const Offset(-1, 0), v.dx < 0);
    arm(const Offset(1, 0), v.dx > 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: armW, height: armW), Radius.circular(a * 0.05)),
      Paint()..color = alpha(base, 0.2),
    );
  }

  @override
  bool shouldRepaint(_DPadPainter o) => o.v != v || o.accent != accent;
}

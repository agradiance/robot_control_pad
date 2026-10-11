import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'common.dart';

/// Artificial horizon. [roll] +right-wing-down, [pitch] +nose-up (radians).
class AttitudeIndicator extends StatelessWidget {
  const AttitudeIndicator({super.key, required this.roll, required this.pitch, this.size = 120});

  final double roll, pitch, size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AttitudePainter(roll, pitch, Theme.of(context).colorScheme.onSurface)),
      );
}

class _AttitudePainter extends CustomPainter {
  _AttitudePainter(this.roll, this.pitch, this.base);
  final double roll, pitch;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final pxPerDeg = r / 25;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-roll);
    canvas.translate(0, pitch * 180 / math.pi * pxPerDeg);
    canvas.drawRect(Rect.fromLTRB(-3 * r, -6 * r, 3 * r, 0), Paint()..color = const Color(0xFF3A7BD5));
    canvas.drawRect(Rect.fromLTRB(-3 * r, 0, 3 * r, 6 * r), Paint()..color = const Color(0xFF8D6E4A));
    final white = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(-3 * r, 0), Offset(3 * r, 0), white);
    for (var deg = -30; deg <= 30; deg += 10) {
      if (deg == 0) continue;
      final y = -deg * pxPerDeg;
      final half = (deg.abs() == 20 ? 0.14 : 0.24) * r;
      canvas.drawLine(Offset(-half, y), Offset(half, y), white..strokeWidth = 1.5);
    }
    canvas.restore();

    canvas.drawCircle(c, r - 1, Paint()..color = alpha(base, 0.6)..style = PaintingStyle.stroke..strokeWidth = 3);
    final plane = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + Offset(-r * 0.6, 0), c + Offset(-r * 0.2, 0), plane);
    canvas.drawLine(c + Offset(r * 0.2, 0), c + Offset(r * 0.6, 0), plane);
    canvas.drawCircle(c, 3, plane);
  }

  @override
  bool shouldRepaint(_AttitudePainter o) => o.roll != roll || o.pitch != pitch;
}

/// Rotating compass card. [headingDegrees]: 0 = north, clockwise.
class HeadingIndicator extends StatelessWidget {
  const HeadingIndicator({super.key, required this.headingDegrees, this.size = 100});

  final double headingDegrees, size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CompassPainter(headingDegrees, Theme.of(context).colorScheme)),
      );
}

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.heading, this.cs);
  final double heading;
  final ColorScheme cs;

  void _label(Canvas canvas, String s, Offset p, Color color, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: fs, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r, Paint()..color = alpha(cs.onSurface, 0.1));
    canvas.drawCircle(c, r - 1, Paint()..color = alpha(cs.onSurface, 0.4)..style = PaintingStyle.stroke..strokeWidth = 2);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * math.pi / 180);
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      final len = i % 9 == 0 ? r * 0.16 : (i % 3 == 0 ? r * 0.1 : r * 0.06);
      final d = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(d * (r * 0.92 - len), d * (r * 0.92), Paint()..color = alpha(cs.onSurface, 0.6));
    }
    const names = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final p = Offset(math.sin(a), -math.cos(a)) * (r * 0.58);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(heading * math.pi / 180);
      _label(canvas, names[i], Offset.zero, i == 0 ? const Color(0xFFE53935) : cs.onSurface, r * 0.26);
      canvas.restore();
    }
    canvas.restore();

    final tri = Path()
      ..moveTo(c.dx, c.dy - r - 1)
      ..lineTo(c.dx - 6, c.dy - r + 10)
      ..lineTo(c.dx + 6, c.dy - r + 10)
      ..close();
    canvas.drawPath(tri, Paint()..color = cs.primary);
    _label(canvas, '${heading.round()}\u00B0', c, cs.onSurface, r * 0.3);
  }

  @override
  bool shouldRepaint(_CompassPainter o) => o.heading != heading;
}

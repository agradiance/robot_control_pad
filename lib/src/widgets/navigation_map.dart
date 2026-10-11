import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../core/telemetry.dart';
import '../core/waypoint.dart';
import 'common.dart';

enum MapTapMode { none, addWaypoint, goTo }

/// Top-down 2D navigation view (x right/east, y up/north, metres).
///
/// * pan / pinch-zoom, follow-robot toggle
/// * robot arrow + breadcrumb trail
/// * tap: add waypoint or send "go to" (see [tapMode]); long-press a waypoint to delete it
/// * play / stop / clear buttons start, cancel and clear the mission
/// * optional [grid] occupancy map (e.g. from SLAM)
class NavigationMap extends StatefulWidget {
  const NavigationMap({
    super.key,
    required this.controller,
    this.tapMode = MapTapMode.addWaypoint,
    this.initialPixelsPerMeter = 40,
    this.showTrail = true,
    this.showButtons = true,
    this.grid,
  });

  final RobotController controller;
  final MapTapMode tapMode;
  final double initialPixelsPerMeter;
  final bool showTrail, showButtons;
  final OccupancyGridData? grid;

  @override
  State<NavigationMap> createState() => _NavigationMapState();
}

class _NavigationMapState extends State<NavigationMap> {
  late double _scale = widget.initialPixelsPerMeter;
  Offset _center = Offset.zero;
  bool _follow = true;
  Size _size = Size.zero;
  double _startScale = 1;
  Offset _lastFocal = Offset.zero;

  Offset get _effectiveCenter {
    final p = widget.controller.telemetry.pose;
    return (_follow && p != null) ? Offset(p.x, p.y) : _center;
  }

  Offset _toWorld(Offset s) {
    final c = _effectiveCenter;
    return Offset(c.dx + (s.dx - _size.width / 2) / _scale, c.dy - (s.dy - _size.height / 2) / _scale);
  }

  Offset _toScreen(Offset w) {
    final c = _effectiveCenter;
    return Offset(_size.width / 2 + (w.dx - c.dx) * _scale, _size.height / 2 - (w.dy - c.dy) * _scale);
  }

  void _onTap(Offset local) {
    final w = _toWorld(local);
    switch (widget.tapMode) {
      case MapTapMode.addWaypoint:
        widget.controller.addWaypoint(w.dx, w.dy);
        break;
      case MapTapMode.goTo:
        widget.controller.goTo(Waypoint(w.dx, w.dy));
        break;
      case MapTapMode.none:
        break;
    }
  }

  void _onLongPress(Offset local) {
    final wps = widget.controller.waypoints;
    var best = -1;
    var bestD = 28.0;
    for (var i = 0; i < wps.length; i++) {
      final d = (_toScreen(Offset(wps[i].x, wps[i].y)) - local).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) widget.controller.removeWaypoint(best);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, cons) {
      _size = cons.biggest;
      return ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          return ClipRect(
            child: Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) {
                    _startScale = _scale;
                    _lastFocal = d.localFocalPoint;
                  },
                  onScaleUpdate: (d) {
                    setState(() {
                      _scale = clampDouble(_startScale * d.scale, 4, 500);
                      final delta = d.localFocalPoint - _lastFocal;
                      _lastFocal = d.localFocalPoint;
                      if (delta != Offset.zero) {
                        if (_follow) {
                          _center = _effectiveCenter;
                          _follow = false;
                        }
                        _center -= Offset(delta.dx, -delta.dy) / _scale;
                      }
                    });
                  },
                  onTapUp: (d) => _onTap(d.localPosition),
                  onLongPressStart: (d) => _onLongPress(d.localPosition),
                  child: CustomPaint(
                    painter: _MapPainter(
                      center: _effectiveCenter,
                      scale: _scale,
                      pose: c.telemetry.pose,
                      trail: widget.showTrail ? List<Pose2D>.of(c.trail) : const [],
                      waypoints: List<Waypoint>.of(c.waypoints),
                      grid: widget.grid,
                      scheme: cs,
                    ),
                  ),
                ),
              ),
              if (widget.showButtons)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Column(children: [
                    _MapButton(Icons.add, 'Zoom in', () => setState(() => _scale = math.min(_scale * 1.5, 500))),
                    _MapButton(Icons.remove, 'Zoom out', () => setState(() => _scale = math.max(_scale / 1.5, 4))),
                    _MapButton(Icons.my_location, 'Follow robot', () => setState(() => _follow = true),
                        highlight: _follow),
                    _MapButton(Icons.play_arrow, 'Start mission', c.startMission),
                    _MapButton(Icons.stop, 'Cancel mission', c.cancelMission),
                    _MapButton(Icons.delete_outline, 'Clear waypoints', c.clearWaypoints),
                  ]),
                ),
            ]),
          );
        },
      );
    });
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton(this.icon, this.tooltip, this.onPressed, {this.highlight = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        isSelected: highlight,
        style: IconButton.styleFrom(backgroundColor: highlight ? cs.primary : null, foregroundColor: highlight ? cs.onPrimary : null),
        icon: Icon(icon),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.center,
    required this.scale,
    required this.pose,
    required this.trail,
    required this.waypoints,
    required this.grid,
    required this.scheme,
  });

  final Offset center;
  final double scale;
  final Pose2D? pose;
  final List<Pose2D> trail;
  final List<Waypoint> waypoints;
  final OccupancyGridData? grid;
  final ColorScheme scheme;

  Offset _s(Size size, double x, double y) =>
      Offset(size.width / 2 + (x - center.dx) * scale, size.height / 2 - (y - center.dy) * scale);

  void _text(Canvas canvas, String s, Offset p, TextStyle style, {bool centered = true}) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, centered ? p - Offset(tp.width / 2, tp.height / 2) : p);
  }

  double _gridStep() {
    for (final s in const [0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 500.0]) {
      if (s * scale >= 40) return s;
    }
    return 1000;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);

    // grid
    final step = _gridStep();
    final x0 = center.dx - size.width / 2 / scale, x1 = center.dx + size.width / 2 / scale;
    final y0 = center.dy - size.height / 2 / scale, y1 = center.dy + size.height / 2 / scale;
    final gridPaint = Paint()..color = alpha(scheme.onSurface, 0.10);
    final axisPaint = Paint()
      ..color = alpha(scheme.onSurface, 0.35)
      ..strokeWidth = 1.5;
    for (var i = (x0 / step).floor(); i <= (x1 / step).ceil(); i++) {
      final sx = _s(size, i * step, 0).dx;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), i == 0 ? axisPaint : gridPaint);
    }
    for (var j = (y0 / step).floor(); j <= (y1 / step).ceil(); j++) {
      final sy = _s(size, 0, j * step).dy;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), j == 0 ? axisPaint : gridPaint);
    }

    // occupancy grid
    final g = grid;
    if (g != null) {
      final occ = Paint()..color = alpha(scheme.onSurface, 0.75);
      final px = g.resolution * scale;
      final screen = Offset.zero & size;
      for (var j = 0; j < g.height; j++) {
        for (var i = 0; i < g.width; i++) {
          if (g.data[j * g.width + i] < 50) continue;
          final p = _s(size, g.originX + i * g.resolution, g.originY + j * g.resolution);
          final rect = Rect.fromLTWH(p.dx, p.dy - px, px + 0.5, px + 0.5);
          if (rect.overlaps(screen)) canvas.drawRect(rect, occ);
        }
      }
    }

    // trail
    if (trail.length > 1) {
      final path = Path();
      for (var i = 0; i < trail.length; i++) {
        final p = _s(size, trail[i].x, trail[i].y);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = alpha(scheme.tertiary, 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // planned route
    if (waypoints.isNotEmpty) {
      final route = Path();
      final start = pose != null ? _s(size, pose!.x, pose!.y) : _s(size, waypoints.first.x, waypoints.first.y);
      route.moveTo(start.dx, start.dy);
      for (final w in waypoints) {
        final p = _s(size, w.x, w.y);
        route.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        route,
        Paint()
          ..color = alpha(scheme.primary, 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = 0; i < waypoints.length; i++) {
        final p = _s(size, waypoints[i].x, waypoints[i].y);
        canvas.drawCircle(p, 12, Paint()..color = scheme.primary);
        _text(canvas, '${i + 1}', p, TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700));
      }
    }

    // robot
    if (pose != null) {
      final p = _s(size, pose!.x, pose!.y);
      final l = (0.4 * scale).clamp(10.0, 28.0).toDouble();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(-pose!.theta);
      final body = Path()
        ..moveTo(l, 0)
        ..lineTo(-l * 0.7, l * 0.6)
        ..lineTo(-l * 0.4, 0)
        ..lineTo(-l * 0.7, -l * 0.6)
        ..close();
      canvas.drawPath(body, Paint()..color = const Color(0xFFFF7043));
      canvas.drawPath(
          body, Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.restore();
    }

    // scale bar
    final barLen = step * scale;
    final y = size.height - 18;
    final bar = Paint()
      ..color = alpha(scheme.onSurface, 0.8)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(16, y), Offset(16 + barLen, y), bar);
    canvas.drawLine(Offset(16, y - 4), Offset(16, y + 4), bar);
    canvas.drawLine(Offset(16 + barLen, y - 4), Offset(16 + barLen, y + 4), bar);
    _text(canvas, '${step >= 1 ? step.toStringAsFixed(0) : step.toStringAsFixed(1)} m', Offset(16, y - 16),
        TextStyle(color: scheme.onSurface, fontSize: 11),
        centered: false);
  }

  @override
  bool shouldRepaint(_MapPainter o) => true;
}

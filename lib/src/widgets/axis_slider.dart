import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'common.dart';

/// Touch slider for throttle, altitude rate, speed limit, brake, gas...
///
/// * [bipolar] false: 0..1 (bottom/left = 0). true: -1..1 with centre 0.
/// * [springBack]: return to 0 on release (gas pedal, climb rate).
///   Otherwise the value is held (throttle lever, speed limit).
/// Vertical sliders report +1 at the top.
class AxisSlider extends StatefulWidget {
  const AxisSlider({
    super.key,
    required this.onChanged,
    this.direction = Axis.vertical,
    this.length = 200,
    this.thickness = 64,
    this.bipolar = false,
    this.springBack = false,
    this.initialValue = 0,
    this.label,
    this.haptics = true,
    this.color,
  });

  final ValueChanged<double> onChanged;
  final Axis direction;
  final double length, thickness;
  final bool bipolar, springBack, haptics;
  final double initialValue;
  final String? label;
  final Color? color;

  @override
  State<AxisSlider> createState() => _AxisSliderState();
}

class _AxisSliderState extends State<AxisSlider> {
  late double _value = widget.initialValue;
  int? _pointer;

  double get _thumb => widget.thickness * 0.9;
  double get _usable => widget.length - _thumb;
  bool get _vertical => widget.direction == Axis.vertical;

  void _fromLocal(Offset p) {
    final along = _vertical ? widget.length - p.dy : p.dx;
    final t = clampDouble((along - _thumb / 2) / _usable, 0, 1);
    var v = widget.bipolar ? t * 2 - 1 : t;
    if (widget.bipolar && v.abs() < 0.03) v = 0;
    if (v != _value) {
      setState(() => _value = v);
      widget.onChanged(v);
    }
  }

  void _release() {
    _pointer = null;
    if (widget.springBack && _value != 0) {
      setState(() => _value = 0);
      widget.onChanged(0);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final track = SizedBox(
      width: _vertical ? widget.thickness : widget.length,
      height: _vertical ? widget.length : widget.thickness,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          if (widget.haptics) HapticFeedback.selectionClick();
          _fromLocal(e.localPosition);
        },
        onPointerMove: (e) {
          if (e.pointer == _pointer) _fromLocal(e.localPosition);
        },
        onPointerUp: (e) {
          if (e.pointer == _pointer) _release();
        },
        onPointerCancel: (e) {
          if (e.pointer == _pointer) _release();
        },
        child: CustomPaint(
          painter: _SliderPainter(
            value: _value,
            vertical: _vertical,
            bipolar: widget.bipolar,
            thumb: _thumb,
            thickness: widget.thickness,
            base: cs.onSurface,
            accent: widget.color ?? cs.primary,
            active: _pointer != null,
          ),
        ),
      ),
    );
    if (widget.label == null) return track;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      track,
      const SizedBox(height: 4),
      Text(widget.label!, style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.value,
    required this.vertical,
    required this.bipolar,
    required this.thumb,
    required this.thickness,
    required this.base,
    required this.accent,
    required this.active,
  });

  final double value, thumb, thickness;
  final bool vertical, bipolar, active;
  final Color base, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final len = vertical ? size.height : size.width;
    final usable = len - thumb;
    double pos(double t) => thumb / 2 + t * usable;
    Offset pt(double along) =>
        vertical ? Offset(size.width / 2, size.height - along) : Offset(along, size.height / 2);

    final trackRect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(thickness / 2.5));
    canvas.drawRRect(trackRect, Paint()..color = alpha(base, 0.10));
    canvas.drawRRect(
        trackRect, Paint()..color = alpha(base, 0.35)..style = PaintingStyle.stroke..strokeWidth = 2);

    final t = bipolar ? (value + 1) / 2 : value;
    final t0 = bipolar ? 0.5 : 0.0;
    canvas.drawLine(
      pt(pos(t0)),
      pt(pos(t)),
      Paint()
        ..color = alpha(accent, 0.55)
        ..strokeWidth = thickness * 0.35
        ..strokeCap = StrokeCap.round,
    );
    if (bipolar) {
      final c = pt(pos(0.5));
      final half = thickness * 0.3;
      canvas.drawLine(
        vertical ? c - Offset(half, 0) : c - Offset(0, half),
        vertical ? c + Offset(half, 0) : c + Offset(0, half),
        Paint()..color = alpha(base, 0.4)..strokeWidth = 2,
      );
    }
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pt(pos(t)),
        width: vertical ? thickness * 0.9 : thumb,
        height: vertical ? thumb : thickness * 0.9,
      ),
      Radius.circular(thickness * 0.25),
    );
    canvas.drawRRect(thumbRect, Paint()..color = active ? accent : alpha(accent, 0.8));
    canvas.drawRRect(
        thumbRect, Paint()..color = alpha(const Color(0xFFFFFFFF), 0.4)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_SliderPainter o) => o.value != value || o.active != active || o.accent != accent;
}

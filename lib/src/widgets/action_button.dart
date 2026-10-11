import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'common.dart';

/// Momentary (hold) or toggle round button. Reports pressed state instantly
/// on pointer down/up - no tap delay.
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.onChanged,
    this.icon,
    this.label,
    this.toggle = false,
    this.initial = false,
    this.size = 64,
    this.color,
  });

  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final String? label;
  final bool toggle;
  final bool initial;
  final double size;
  final Color? color;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  late bool _on = widget.initial;
  int? _pointer;

  void _set(bool v) {
    if (v == _on) return;
    setState(() => _on = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.color ?? cs.primary;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        HapticFeedback.selectionClick();
        _set(widget.toggle ? !_on : true);
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        _pointer = null;
        if (!widget.toggle) _set(false);
      },
      onPointerCancel: (e) {
        if (e.pointer != _pointer) return;
        _pointer = null;
        if (!widget.toggle) _set(false);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _on ? accent : alpha(cs.onSurface, 0.12),
          border: Border.all(color: _on ? accent : alpha(cs.onSurface, 0.35), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.icon != null)
            Icon(widget.icon, size: widget.size * 0.4, color: _on ? cs.onPrimary : cs.onSurface),
          if (widget.label != null)
            Text(
              widget.label!,
              style: TextStyle(
                fontSize: widget.size * 0.18,
                fontWeight: FontWeight.w600,
                color: _on ? cs.onPrimary : cs.onSurface,
              ),
            ),
        ]),
      ),
    );
  }
}

import 'dart:ui' show FontFeature;

import 'package:material_ui/material_ui.dart';

import '../controller/robot_controller.dart';
import '../transport/robot_transport.dart';
import 'common.dart';

class LinkStatusChip extends StatelessWidget {
  const LinkStatusChip({super.key, required this.status, this.stale = false});

  final LinkStatus status;

  /// Connected but no telemetry for a while.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String text;
    switch (status) {
      case LinkStatus.connected:
        color = stale ? const Color(0xFFFFA000) : const Color(0xFF43A047);
        text = stale ? 'NO DATA' : 'LINK';
        break;
      case LinkStatus.connecting:
        color = const Color(0xFFFFA000);
        text = 'CONNECTING';
        break;
      case LinkStatus.failed:
        color = const Color(0xFFE53935);
        text = 'FAILED';
        break;
      case LinkStatus.disconnected:
        color = const Color(0xFFE53935);
        text = 'OFFLINE';
        break;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    ]);
  }
}

class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key, this.percent, this.voltage});

  final double? percent, voltage;

  @override
  Widget build(BuildContext context) {
    final p = percent;
    final IconData icon;
    Color? color;
    if (p == null) {
      icon = Icons.battery_unknown;
    } else if (p <= 15) {
      icon = Icons.battery_alert;
      color = const Color(0xFFE53935);
    } else if (p <= 40) {
      icon = Icons.battery_3_bar;
      color = const Color(0xFFFFA000);
    } else if (p <= 70) {
      icon = Icons.battery_5_bar;
    } else {
      icon = Icons.battery_full;
    }
    final text = [
      if (p != null) '${p.round()}%',
      if (voltage != null) '${voltage!.toStringAsFixed(1)}V',
    ].join(' ');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 2),
      Text(text.isEmpty ? '--' : text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()])),
      ]);
}

/// Compact status strip: link, battery, mode, speed, altitude, heading.
class TelemetryBar extends StatelessWidget {
  const TelemetryBar({
    super.key,
    required this.controller,
    this.showSpeed = true,
    this.showAltitude = true,
    this.showHeading = true,
    this.trailing,
  });

  final RobotController controller;
  final bool showSpeed, showAltitude, showHeading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = controller.telemetry;
        const gap = SizedBox(width: 16);
        return Material(
          color: alpha(cs.surfaceContainerHighest, 0.85),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                LinkStatusChip(
                  status: controller.linkStatus,
                  stale:
                      controller.isConnected && controller.isTelemetryStale(),
                ),
                gap,
                BatteryIndicator(
                    percent: t.batteryPercent, voltage: t.batteryVoltage),
                gap,
                _Metric(Icons.tune, (t.mode ?? controller.mode).toUpperCase()),
                if (showSpeed && t.speed != null) ...[
                  gap,
                  _Metric(Icons.speed, '${t.speed!.toStringAsFixed(1)} m/s')
                ],
                if (showAltitude && t.altitude != null) ...[
                  gap,
                  _Metric(Icons.height, '${t.altitude!.toStringAsFixed(1)} m'),
                ],
                if (showHeading && t.headingDegrees != null) ...[
                  gap,
                  _Metric(Icons.explore, '${t.headingDegrees!.round()}\u00B0'),
                ],
                if (trailing != null) ...[gap, trailing!],
              ]),
            ),
          ),
        );
      },
    );
  }
}

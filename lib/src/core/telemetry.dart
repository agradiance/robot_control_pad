import 'dart:math' as math;

/// Planar pose in a map frame: x east/right, y north/up (metres),
/// theta counter-clockwise from +x (radians).
class Pose2D {
  const Pose2D(this.x, this.y, this.theta);
  final double x, y, theta;
}

/// Everything is optional; sources deliver partial updates which the
/// controller merges with [merge].
///
/// Attitude uses aviation convention (for the artificial horizon):
/// roll +right-wing-down, pitch +nose-up, both in radians. [yaw] is radians
/// counter-clockwise from +x.
class Telemetry {
  const Telemetry({
    this.batteryPercent,
    this.batteryVoltage,
    this.pose,
    this.speed,
    this.altitude,
    this.heading,
    this.roll,
    this.pitch,
    this.yaw,
    this.linkQuality,
    this.mode,
    this.extras = const {},
  });

  final double? batteryPercent; // 0..100
  final double? batteryVoltage;
  final Pose2D? pose;
  final double? speed; // m/s
  final double? altitude; // m
  final double? heading; // compass degrees (0 = north, clockwise); overrides yaw
  final double? roll, pitch, yaw;
  final double? linkQuality; // 0..1
  final String? mode;
  final Map<String, dynamic> extras;

  /// Compass heading in degrees (0 = north, clockwise).
  double? get headingDegrees {
    if (heading != null) return heading! % 360;
    final t = yaw ?? pose?.theta;
    if (t == null) return null;
    return (90 - t * 180 / math.pi) % 360;
  }

  Telemetry merge(Telemetry o) => Telemetry(
        batteryPercent: o.batteryPercent ?? batteryPercent,
        batteryVoltage: o.batteryVoltage ?? batteryVoltage,
        pose: o.pose ?? pose,
        speed: o.speed ?? speed,
        altitude: o.altitude ?? altitude,
        heading: o.heading ?? heading,
        roll: o.roll ?? roll,
        pitch: o.pitch ?? pitch,
        yaw: o.yaw ?? yaw,
        linkQuality: o.linkQuality ?? linkQuality,
        mode: o.mode ?? mode,
        extras: {...extras, ...o.extras},
      );
}

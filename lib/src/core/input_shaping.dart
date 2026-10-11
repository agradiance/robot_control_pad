import 'control_config.dart';

double clampUnit(double v) => v < -1 ? -1 : (v > 1 ? 1 : v);

/// Removes the centre dead band and rescales so output still reaches +-1.
double applyDeadzone(double v, double deadzone) {
  final dz = deadzone.clamp(0.0, 0.99).toDouble();
  final a = v.abs();
  if (a <= dz) return 0;
  return v.sign * (a - dz) / (1 - dz);
}

/// Blends linear and cubic response. [expo] 0..1.
double applyExpo(double v, double expo) {
  final e = expo.clamp(0.0, 1.0).toDouble();
  return (1 - e) * v + e * v * v * v;
}

double shapeAxis(double v, AxisConfig c) {
  var out = applyExpo(applyDeadzone(clampUnit(v), c.deadzone), c.expo) * c.scale;
  if (c.invert) out = -out;
  return clampUnit(out);
}

/// Limits how fast an output may change (units / second).
class SlewLimiter {
  double value = 0;

  double step(double target, double dt, double? rate) {
    if (rate == null) return value = target;
    final maxDelta = rate * dt;
    final delta = target - value;
    if (delta.abs() <= maxDelta) return value = target;
    return value += maxDelta * delta.sign;
  }

  void reset() => value = 0;
}

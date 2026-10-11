import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_pad/robot_control_pad.dart';

void main() {
  test('deadzone zeroes small inputs and rescales the rest', () {
    expect(applyDeadzone(0.04, 0.1), 0);
    expect(applyDeadzone(1.0, 0.1), closeTo(1.0, 1e-9));
    expect(applyDeadzone(-0.55, 0.1), closeTo(-0.5, 1e-9));
  });

  test('expo softens the centre but keeps the ends', () {
    expect(applyExpo(0.5, 1), closeTo(0.125, 1e-9));
    expect(applyExpo(1, 1), 1);
    expect(applyExpo(0.5, 0), 0.5);
  });

  test('shapeAxis applies scale and invert', () {
    const c = AxisConfig(deadzone: 0, scale: 0.5, invert: true);
    expect(shapeAxis(1, c), -0.5);
  });

  test('slew limiter caps rate of change', () {
    final s = SlewLimiter();
    expect(s.step(1, 0.1, 2), closeTo(0.2, 1e-9));
    expect(s.step(1, 0.1, 2), closeTo(0.4, 1e-9));
    expect(s.step(0, 1, null), 0);
  });
}

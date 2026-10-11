import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_pad/robot_control_pad.dart';

class _RecordingTransport extends RobotTransport {
  _RecordingTransport() : super(protocol: const JsonProtocol());
  final commands = <ControlCommand>[];
  final events = <String>[];

  @override
  Future<void> connect() async => setStatus(LinkStatus.connected);
  @override
  Future<void> disconnect() async => setStatus(LinkStatus.disconnected);
  @override
  void send(Object data) {}
  @override
  void sendCommand(ControlCommand c) => commands.add(c);
  @override
  void sendEvent(String name, [Map<String, dynamic> data = const {}]) => events.add(name);
}

void main() {
  testWidgets('streams shaped commands; sources sum; e-stop zeroes output', (tester) async {
    final t = _RecordingTransport();
    final c = RobotController(
      transport: t,
      config: const ControlConfig(sendRateHz: 50, defaultAxis: AxisConfig(deadzone: 0)),
    );

    c.setAxis(ControlAxis.surge, 0.5);
    c.setAxis(ControlAxis.surge, 0.25, source: 'keyboard');
    await tester.pump(const Duration(milliseconds: 100));
    expect(t.commands, isNotEmpty);
    expect(t.commands.last.surge, closeTo(0.75, 1e-9));

    c.speedScale = 0.5;
    await tester.pump(const Duration(milliseconds: 100));
    expect(t.commands.last.surge, closeTo(0.375, 1e-9));

    c.emergencyStop();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.isEmergencyStopped, isTrue);
    expect(t.commands.last.isNeutral, isTrue);
    expect(t.events.where((e) => e == 'estop').length, 3);

    c.dispose();
    await tester.pump();
  });

  testWidgets('requireArm blocks output until armed', (tester) async {
    final t = _RecordingTransport();
    final c = RobotController(
      transport: t,
      config: const ControlConfig(sendRateHz: 50, requireArm: true, defaultAxis: AxisConfig(deadzone: 0)),
    );
    c.setAxis(ControlAxis.yaw, 1);
    await tester.pump(const Duration(milliseconds: 60));
    expect(t.commands.last.yaw, 0);
    c.arm();
    await tester.pump(const Duration(milliseconds: 60));
    expect(t.commands.last.yaw, 1);
    c.dispose();
    await tester.pump();
  });
}

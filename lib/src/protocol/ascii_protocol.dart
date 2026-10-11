import '../core/control_command.dart';
import '../core/telemetry.dart';
import 'robot_protocol.dart';

/// Tiny newline-terminated text protocol for Arduino / ESP32 / STM32 over
/// UDP, TCP or a serial-to-network bridge.
///
///   -> `C,surge,sway,heave,roll,pitch,yaw,buttonMask\n`
///   -> `E,name[,key=value...]\n`
///   <- `T,battery%,voltage,speed,altitude,headingDeg\n`   (fields may be empty)
///
/// Button bit i corresponds to `buttonOrder[i]`.
class AsciiLineProtocol extends RobotProtocol {
  const AsciiLineProtocol({this.buttonOrder = const [], this.decimals = 3});

  final List<String> buttonOrder;
  final int decimals;

  @override
  bool get lineDelimited => true;

  String _f(double v) => v.toStringAsFixed(decimals);

  @override
  Object encodeCommand(ControlCommand c) {
    var mask = 0;
    for (var i = 0; i < buttonOrder.length; i++) {
      if (c.buttons[buttonOrder[i]] == true) mask |= 1 << i;
    }
    return 'C,${_f(c.surge)},${_f(c.sway)},${_f(c.heave)},${_f(c.roll)},${_f(c.pitch)},${_f(c.yaw)},$mask\n';
  }

  @override
  Object? encodeEvent(String name, [Map<String, dynamic> data = const {}]) {
    final kv = data.entries.where((e) => e.value is! Iterable && e.value is! Map).map((e) => '${e.key}=${e.value}');
    return 'E,$name${kv.isEmpty ? '' : ',${kv.join(',')}'}\n';
  }

  @override
  Telemetry? decodeTelemetry(Object data) {
    final lines = asText(data).split('\n');
    for (final raw in lines.reversed) {
      final line = raw.trim();
      if (!line.startsWith('T,')) continue;
      final p = line.split(',');
      double? at(int i) => i < p.length ? double.tryParse(p[i]) : null;
      return Telemetry(
        batteryPercent: at(1),
        batteryVoltage: at(2),
        speed: at(3),
        altitude: at(4),
        heading: at(5),
      );
    }
    return null;
  }
}

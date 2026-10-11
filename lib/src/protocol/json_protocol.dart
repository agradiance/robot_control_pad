import 'dart:convert';

import '../core/control_command.dart';
import '../core/telemetry.dart';
import 'robot_protocol.dart';

/// Plain JSON messages - easiest to implement on a Raspberry Pi / Jetson /
/// ESP32 / Python server.
///
///   -> {"type":"cmd","seq":1,"surge":0.5,"sway":0,"heave":0,"roll":0,"pitch":0,"yaw":-0.2,"buttons":{}}
///   -> {"type":"event","name":"takeoff","data":{}}
///   <- {"type":"telemetry","battery":87,"voltage":11.8,"x":1.2,"y":0.4,"theta":0.3,
///       "speed":0.5,"altitude":2.0,"roll":0.0,"pitch":0.0,"yaw":0.3,"link":0.9,"mode":"AUTO"}
class JsonProtocol extends RobotProtocol {
  const JsonProtocol();

  @override
  Object encodeCommand(ControlCommand c) => jsonEncode({'type': 'cmd', ...c.toJson()});

  @override
  Object? encodeEvent(String name, [Map<String, dynamic> data = const {}]) =>
      jsonEncode({'type': 'event', 'name': name, 'data': data});

  @override
  Telemetry? decodeTelemetry(Object data) {
    try {
      final m = jsonDecode(asText(data));
      if (m is! Map || m['type'] != 'telemetry') return null;
      return telemetryFromJson(m.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static Telemetry telemetryFromJson(Map<String, dynamic> m) {
    final x = asDouble(m['x']);
    final y = asDouble(m['y']);
    final extras = m['extras'];
    return Telemetry(
      batteryPercent: asDouble(m['battery']),
      batteryVoltage: asDouble(m['voltage']),
      pose: (x != null && y != null) ? Pose2D(x, y, asDouble(m['theta']) ?? 0) : null,
      speed: asDouble(m['speed']),
      altitude: asDouble(m['altitude']),
      heading: asDouble(m['heading']),
      roll: asDouble(m['roll']),
      pitch: asDouble(m['pitch']),
      yaw: asDouble(m['yaw']),
      linkQuality: asDouble(m['link']),
      mode: m['mode'] as String?,
      extras: extras is Map ? extras.cast<String, dynamic>() : const {},
    );
  }
}

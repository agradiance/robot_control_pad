import 'dart:convert';
import 'dart:math' as math;

import '../core/control_command.dart';
import '../core/telemetry.dart';
import 'robot_protocol.dart';

/// Talks to ROS / ROS 2 through `rosbridge_server` (WebSocket, default port 9090).
///
/// * Commands -> `geometry_msgs/Twist` (or `TwistStamped`) on [cmdVelTopic],
///   scaled by [maxLinear] (m/s), [maxVertical] (m/s) and [maxAngular] (rad/s).
/// * `goto`  event -> `geometry_msgs/PoseStamped` on [goalTopic].
/// * `waypoints` event -> `nav_msgs/Path` on [pathTopic].
/// * Telemetry from `nav_msgs/Odometry` ([odomTopic]) and
///   `sensor_msgs/BatteryState` ([batteryTopic]).
///
/// Anything else (arm, takeoff, ...) can be mapped with [customEvent].
class RosbridgeProtocol extends RobotProtocol {
  const RosbridgeProtocol({
    this.cmdVelTopic = '/cmd_vel',
    this.odomTopic = '/odom',
    this.batteryTopic,
    this.goalTopic = '/goal_pose',
    this.pathTopic = '/waypoints',
    this.maxLinear = 1.0,
    this.maxVertical = 1.0,
    this.maxAngular = 1.5,
    this.stamped = false,
    this.ros2 = true,
    this.frameId = 'base_link',
    this.mapFrame = 'map',
    this.customEvent,
  });

  final String cmdVelTopic;
  final String? odomTopic, batteryTopic, goalTopic, pathTopic;
  final double maxLinear, maxVertical, maxAngular;
  final bool stamped;
  final bool ros2;
  final String frameId, mapFrame;

  /// Return a complete rosbridge JSON string (or null) for an event.
  final String? Function(String name, Map<String, dynamic> data)? customEvent;

  String _type(String pkg, String name) => ros2 ? '$pkg/msg/$name' : '$pkg/$name';

  @override
  List<Object> handshake() => [
        jsonEncode({
          'op': 'advertise',
          'topic': cmdVelTopic,
          'type': _type('geometry_msgs', stamped ? 'TwistStamped' : 'Twist'),
        }),
        if (goalTopic != null)
          jsonEncode({'op': 'advertise', 'topic': goalTopic, 'type': _type('geometry_msgs', 'PoseStamped')}),
        if (pathTopic != null)
          jsonEncode({'op': 'advertise', 'topic': pathTopic, 'type': _type('nav_msgs', 'Path')}),
        if (odomTopic != null)
          jsonEncode({'op': 'subscribe', 'topic': odomTopic, 'type': _type('nav_msgs', 'Odometry'), 'throttle_rate': 50}),
        if (batteryTopic != null)
          jsonEncode({'op': 'subscribe', 'topic': batteryTopic, 'type': _type('sensor_msgs', 'BatteryState')}),
      ];

  Map<String, dynamic> _twist(ControlCommand c) => {
        'linear': {'x': c.surge * maxLinear, 'y': c.sway * maxLinear, 'z': c.heave * maxVertical},
        'angular': {'x': c.roll * maxAngular, 'y': c.pitch * maxAngular, 'z': c.yaw * maxAngular},
      };

  @override
  Object encodeCommand(ControlCommand c) {
    Map<String, dynamic> msg = _twist(c);
    if (stamped) {
      final us = DateTime.now().microsecondsSinceEpoch;
      msg = {
        'header': {
          'stamp': {'sec': us ~/ 1000000, 'nanosec': (us % 1000000) * 1000},
          'frame_id': frameId,
        },
        'twist': msg,
      };
    }
    return jsonEncode({'op': 'publish', 'topic': cmdVelTopic, 'msg': msg});
  }

  Map<String, dynamic> _pose(double x, double y, double th) => {
        'header': {'frame_id': mapFrame},
        'pose': {
          'position': {'x': x, 'y': y, 'z': 0.0},
          'orientation': {'x': 0.0, 'y': 0.0, 'z': math.sin(th / 2), 'w': math.cos(th / 2)},
        },
      };

  @override
  Object? encodeEvent(String name, [Map<String, dynamic> data = const {}]) {
    final custom = customEvent?.call(name, data);
    if (custom != null) return custom;
    if (name == 'goto' && goalTopic != null) {
      final msg = _pose(asDouble(data['x']) ?? 0, asDouble(data['y']) ?? 0, asDouble(data['theta']) ?? 0);
      return jsonEncode({'op': 'publish', 'topic': goalTopic, 'msg': msg});
    }
    if (name == 'waypoints' && pathTopic != null) {
      final pts = (data['points'] as List? ?? const []).cast<Map>();
      final msg = {
        'header': {'frame_id': mapFrame},
        'poses': [
          for (final p in pts)
            _pose(asDouble(p['x']) ?? 0, asDouble(p['y']) ?? 0, asDouble(p['theta']) ?? 0),
        ],
      };
      return jsonEncode({'op': 'publish', 'topic': pathTopic, 'msg': msg});
    }
    return null;
  }

  Map? _m(Object? o) => o is Map ? o : null;

  @override
  Telemetry? decodeTelemetry(Object data) {
    try {
      final m = jsonDecode(asText(data));
      if (m is! Map || m['op'] != 'publish') return null;
      final topic = m['topic'];
      final msg = _m(m['msg']);
      if (msg == null) return null;

      if (topic == odomTopic) {
        final pose = _m(_m(msg['pose'])?['pose']);
        final pos = _m(pose?['position']);
        final q = _m(pose?['orientation']);
        final lin = _m(_m(_m(msg['twist'])?['twist'])?['linear']);
        double? yaw;
        if (q != null) {
          final x = asDouble(q['x']) ?? 0, y = asDouble(q['y']) ?? 0;
          final z = asDouble(q['z']) ?? 0, w = asDouble(q['w']) ?? 1;
          yaw = math.atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z));
        }
        final px = asDouble(pos?['x']), py = asDouble(pos?['y']);
        final vx = asDouble(lin?['x']) ?? 0, vy = asDouble(lin?['y']) ?? 0;
        return Telemetry(
          pose: (px != null && py != null) ? Pose2D(px, py, yaw ?? 0) : null,
          yaw: yaw,
          altitude: asDouble(pos?['z']),
          speed: lin != null ? math.sqrt(vx * vx + vy * vy) : null,
        );
      }
      if (topic == batteryTopic) {
        final p = asDouble(msg['percentage']);
        return Telemetry(
          batteryPercent: (p == null || p.isNaN) ? null : (p <= 1.0 ? p * 100 : p),
          batteryVoltage: asDouble(msg['voltage']),
        );
      }
    } catch (_) {}
    return null;
  }
}

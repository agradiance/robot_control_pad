import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_pad/robot_control_pad.dart';

void main() {
  const cmd = ControlCommand(surge: 0.5, yaw: -0.25, buttons: {'horn': true}, sequence: 7);

  test('json command and telemetry', () {
    const p = JsonProtocol();
    final m = jsonDecode(p.encodeCommand(cmd) as String) as Map;
    expect(m['type'], 'cmd');
    expect(m['surge'], 0.5);
    final t = p.decodeTelemetry('{"type":"telemetry","battery":80,"x":1,"y":2,"theta":0.5}');
    expect(t!.batteryPercent, 80);
    expect(t.pose!.y, 2);
    expect(p.decodeTelemetry('{"type":"other"}'), isNull);
  });

  test('ascii protocol encodes button mask and parses telemetry', () {
    const p = AsciiLineProtocol(buttonOrder: ['light', 'horn']);
    expect(p.encodeCommand(cmd), 'C,0.500,0.000,0.000,0.000,0.000,-0.250,2\n');
    expect(p.encodeEvent('takeoff'), 'E,takeoff\n');
    final t = p.decodeTelemetry('T,87,11.8,1.5,,270\n');
    expect(t!.batteryPercent, 87);
    expect(t.altitude, isNull);
    expect(t.heading, 270);
  });

  test('binary frame is well formed and telemetry round-trips', () {
    const p = BinaryProtocol(buttonOrder: ['horn']);
    final f = p.encodeCommand(cmd) as Uint8List;
    expect(f.sublist(0, 4), [0xAA, 0x55, 0x01, 15]);
    var x = 0x01 ^ 15;
    for (var i = 4; i < f.length - 1; i++) {
      x ^= f[i];
    }
    expect(f.last, x);

    final bd = ByteData(9)
      ..setUint8(0, 55)
      ..setInt16(1, 150, Endian.little)
      ..setInt16(3, 320, Endian.little)
      ..setUint16(5, 1800, Endian.little);
    final frame = BinaryProtocol.buildFrame(BinaryProtocol.typeTelemetry, bd.buffer.asUint8List().sublist(0, 7));
    final t = p.decodeTelemetry(frame);
    expect(t!.batteryPercent, 55);
    expect(t.speed, 1.5);
    expect(t.altitude, 3.2);
    expect(t.heading, 180);
    frame[frame.length - 1] ^= 0xFF; // corrupt checksum
    expect(p.decodeTelemetry(frame), isNull);
  });

  test('rosbridge publishes scaled Twist and decodes odometry', () {
    const p = RosbridgeProtocol(maxLinear: 2, maxAngular: 3, batteryTopic: '/battery');
    final m = jsonDecode(p.encodeCommand(cmd) as String) as Map;
    expect(m['topic'], '/cmd_vel');
    expect(m['msg']['linear']['x'], 1.0);
    expect(m['msg']['angular']['z'], -0.75);
    expect(p.handshake().length, 5);

    final odom = jsonEncode({
      'op': 'publish',
      'topic': '/odom',
      'msg': {
        'pose': {
          'pose': {
            'position': {'x': 1.5, 'y': -2.0, 'z': 0.0},
            'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.7071068, 'w': 0.7071068},
          }
        },
        'twist': {'twist': {'linear': {'x': 0.3, 'y': 0.4, 'z': 0.0}}},
      },
    });
    final t = p.decodeTelemetry(odom)!;
    expect(t.pose!.x, 1.5);
    expect(t.pose!.theta, closeTo(1.5708, 1e-3));
    expect(t.speed, closeTo(0.5, 1e-9));
  });
}

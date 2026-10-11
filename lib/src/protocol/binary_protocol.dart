import 'dart:typed_data';

import '../core/control_command.dart';
import '../core/telemetry.dart';
import 'robot_protocol.dart';

/// Compact framed binary protocol for bandwidth-limited links (UDP, telemetry
/// radios, BLE bridges). Little endian.
///
/// Frame: `0xAA 0x55 | type | len | payload[len] | xor(type,len,payload)`
///
/// * type 0x01 command  payload (15 B): 6 x int16 (surge, sway, heave, roll,
///   pitch, yaw; value*32767), uint16 button mask, uint8 sequence
/// * type 0x02 event    payload (1 B): event id from [eventIds]
/// * type 0x10 telemetry payload: uint8 battery %, int16 speed*100,
///   int16 altitude*100, uint16 heading*10
///
/// Each datagram must contain one whole frame (stream reassembly for TCP is
/// not implemented).
class BinaryProtocol extends RobotProtocol {
  const BinaryProtocol({
    this.buttonOrder = const [],
    this.eventIds = const {
      'arm': 1,
      'disarm': 2,
      'estop': 3,
      'estop_reset': 4,
      'takeoff': 5,
      'land': 6,
      'rth': 7,
      'cancel': 8,
    },
  });

  final List<String> buttonOrder;
  final Map<String, int> eventIds;

  static const int sync0 = 0xAA, sync1 = 0x55;
  static const int typeCommand = 0x01, typeEvent = 0x02, typeTelemetry = 0x10;

  static Uint8List buildFrame(int type, List<int> payload) {
    final out = Uint8List(payload.length + 5);
    out[0] = sync0;
    out[1] = sync1;
    out[2] = type;
    out[3] = payload.length;
    out.setRange(4, 4 + payload.length, payload);
    var x = type ^ payload.length;
    for (final b in payload) {
      x ^= b;
    }
    out[out.length - 1] = x & 0xFF;
    return out;
  }

  static int _q(double v) => (v.clamp(-1.0, 1.0) * 32767).round();

  @override
  Object encodeCommand(ControlCommand c) {
    var mask = 0;
    for (var i = 0; i < buttonOrder.length && i < 16; i++) {
      if (c.buttons[buttonOrder[i]] == true) mask |= 1 << i;
    }
    final bd = ByteData(15);
    final axes = [c.surge, c.sway, c.heave, c.roll, c.pitch, c.yaw];
    for (var i = 0; i < 6; i++) {
      bd.setInt16(i * 2, _q(axes[i]), Endian.little);
    }
    bd.setUint16(12, mask, Endian.little);
    bd.setUint8(14, c.sequence & 0xFF);
    return buildFrame(typeCommand, bd.buffer.asUint8List());
  }

  @override
  Object? encodeEvent(String name, [Map<String, dynamic> data = const {}]) {
    final id = eventIds[name];
    return id == null ? null : buildFrame(typeEvent, [id]);
  }

  @override
  Telemetry? decodeTelemetry(Object data) {
    if (data is! List<int> || data.length < 5) return null;
    final b = Uint8List.fromList(data);
    if (b[0] != sync0 || b[1] != sync1) return null;
    final len = b[3];
    if (b.length < len + 5 || b[2] != typeTelemetry || len < 7) return null;
    var x = b[2] ^ len;
    for (var i = 0; i < len; i++) {
      x ^= b[4 + i];
    }
    if ((x & 0xFF) != b[4 + len]) return null;
    final bd = ByteData.sublistView(b, 4, 4 + len);
    return Telemetry(
      batteryPercent: bd.getUint8(0).toDouble(),
      speed: bd.getInt16(1, Endian.little) / 100,
      altitude: bd.getInt16(3, Endian.little) / 100,
      heading: bd.getUint16(5, Endian.little) / 10,
    );
  }
}

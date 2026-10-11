import 'dart:convert';

import '../core/control_command.dart';
import '../core/telemetry.dart';

/// Turns commands/events into bytes (or text) for the wire, and incoming data
/// into [Telemetry]. Swap protocols to talk to different robot stacks without
/// touching any UI code.
abstract class RobotProtocol {
  const RobotProtocol();

  /// Messages sent right after the link opens (advertise/subscribe, hello...).
  List<Object> handshake() => const [];

  /// `String` or `List<int>`.
  Object encodeCommand(ControlCommand command);

  /// Discrete events: arm, disarm, estop, estop_reset, takeoff, land, rth,
  /// goto, waypoints, cancel, mode. Return `null` if unsupported.
  Object? encodeEvent(String name, [Map<String, dynamic> data = const {}]);

  /// Return `null` when [data] is not telemetry.
  Telemetry? decodeTelemetry(Object data);

  /// True if the stream protocol (TCP) is newline-delimited text.
  bool get lineDelimited => false;
}

List<int> asBytes(Object data) =>
    data is String ? utf8.encode(data) : List<int>.from(data as List<int>);

String asText(Object data) =>
    data is String ? data : utf8.decode(data as List<int>, allowMalformed: true);

double? asDouble(Object? v) => v is num ? v.toDouble() : null;

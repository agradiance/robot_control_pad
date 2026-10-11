# robot_control_pad

Flutter control pads, telemetry HUD and a navigation map for driving **mobile robots, cars, drones, rovers, arms' bases** and anything that takes velocity commands. UI, protocol and transport are separate layers, so the same pad can drive a ROS 2 robot, an ESP32 over UDP or a Python server over WebSocket.

```
 widgets / pads  ->  RobotController  ->  RobotTransport  ->  RobotProtocol  ->  robot
 (joystick, wheel,   shaping, arm,        WebSocket, UDP,     JSON, rosbridge,
  map, HUD)          e-stop, heartbeat    TCP, Mock           ASCII, binary
```

## What's included

**Input widgets** `VirtualJoystick` (multi-touch, circular/square, axis lock, spring or hold), `AxisSlider` (throttle / brake / speed limit), `DPad` (4/8-way), `SteeringWheel`, `ActionButton` (hold or toggle), `KeyboardControlInput` (WASD for desktop/web).

**Safety** `EmergencyStopButton` (instant, hold-to-reset), `ArmSlider`, arm gate (`requireArm`), zero-on-background, auto-disarm on link loss, 30 Hz heartbeat stream.

**Feedback** `TelemetryBar`, `LinkStatusChip`, `BatteryIndicator`, `AttitudeIndicator` (artificial horizon), `HeadingIndicator`.

**Navigation** `NavigationMap`: pan/zoom, robot arrow, trail, tap-to-add waypoints, long-press to delete, go-to / run / cancel mission, optional occupancy grid.

**Ready-made pads** `DifferentialDrivePad` (arcade / twin-stick / tank), `OmniDrivePad` (mecanum), `CarControlPad`, `DroneControlPad` (mode 1/2), `NavigationPad`.

**Input shaping** deadzone, expo, per-axis scale, invert, slew-rate (acceleration) limit, global speed limit.

**Transports** `WebSocketTransport` (auto-reconnect, all platforms), `UdpTransport`, `TcpTransport` (`robot_control_pad_io.dart`, not web), `MockTransport` (built-in simulator, no hardware needed).

**Protocols** `RosbridgeProtocol` (ROS 1/2 Twist, odom, battery, goal pose, path), `JsonProtocol`, `AsciiLineProtocol` (Arduino/ESP32 friendly), `BinaryProtocol` (framed, checksummed).

## Quick start

```dart
final controller = RobotController(
  transport: WebSocketTransport(
    uri: Uri.parse('ws://192.168.1.50:9090'),          // rosbridge_server
    protocol: const RosbridgeProtocol(maxLinear: 0.5, maxAngular: 1.0),
  ),
  config: const ControlConfig(defaultAxis: AxisConfig(deadzone: 0.08, expo: 0.3)),
);
await controller.connect();

// in build():
DifferentialDrivePad(controller: controller);
```

No robot yet? `transport: MockTransport()` simulates one (also `MockRobotKind.drone`).

UDP to a microcontroller:

```dart
import 'package:robot_control_pad/robot_control_pad_io.dart';
transport: UdpTransport(host: '192.168.4.1', port: 4210,
    protocol: const AsciiLineProtocol(buttonOrder: ['light', 'horn'])),
```

Keyboard teleop: `KeyboardControlInput(controller: c, child: pad)`.

Custom layout: place widgets yourself and feed the controller:

```dart
VirtualJoystick(onChanged: (v) =>
    controller.setAxes({ControlAxis.surge: v.dy, ControlAxis.yaw: -v.dx}));
```

## Axis conventions (ROS REP-103)

All values -1..1: `surge` +forward, `sway` +**left**, `heave` +up, `yaw` +**counter-clockwise (left)**. Widgets report right/up as positive, so pads negate x for sway/yaw. Cars carry normalised steering (+left) in `yaw`. Map and pose frames: x right/east, y up/north, theta CCW from +x.

## Wire formats

JSON: `-> {"type":"cmd","seq":1,"surge":0.5,"yaw":-0.2,...}`, `-> {"type":"event","name":"takeoff","data":{}}`, `<- {"type":"telemetry","battery":87,"x":1.2,"y":0.4,"theta":0.3,...}`.
Events sent by the controller: `arm`, `disarm`, `estop`, `estop_reset`, `takeoff`, `land`, `rth`, `goto`, `waypoints`, `cancel`, `mode`.
ASCII and binary layouts are documented in their class comments.

## Add your own transport (Bluetooth, serial, MQTT...)

```dart
class BleTransport extends RobotTransport {
  BleTransport(): super(protocol: const BinaryProtocol());
  Future<void> connect() async { /* open link */ setStatus(LinkStatus.connected); }
  Future<void> disconnect() async { setStatus(LinkStatus.disconnected); }
  void send(Object data) { /* write bytes */ }
  // call handleIncoming(bytes) when data arrives
}
```
Gamepads: poll them with a package such as `gamepads` and call `controller.setAxes({...}, source: 'gamepad')`; sources are summed with touch/keyboard input.

## Safety - please read

* The software e-stop is **not** a safety device. Keep a hardware kill switch.
* Implement a **watchdog on the robot**: if no command arrives for ~300 ms, stop. The 30 Hz command stream is the heartbeat; the pad never relies on "release" messages alone.
* UDP is lossy: the e-stop event is sent 3x, but the watchdog is what actually protects you.
* Test with wheels/props off the ground first.

## Status

Written without a Flutter SDK available in the authoring environment: it has **not been compiled or run**. Run `flutter pub get && flutter analyze && flutter test` first and expect to fix small things. Example app: `cd example && flutter create . && flutter run`.

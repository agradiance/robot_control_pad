import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:robot_control_pad/robot_control_pad.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Robot Control Pad',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange, brightness: Brightness.dark, useMaterial3: true),
        home: const DemoHome(),
      );
}

enum Layout { arcade, tank, omni, car, drone, navigation }

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  Layout _layout = Layout.arcade;
  String _url = ''; // empty = built-in simulator
  late RobotController _c;

  @override
  void initState() {
    super.initState();
    _c = _build();
  }

  RobotController _build() {
    final RobotTransport transport = _url.isEmpty
        ? MockTransport(kind: _layout == Layout.drone ? MockRobotKind.drone : MockRobotKind.ground)
        : WebSocketTransport(
            uri: Uri.parse(_url),
            // Use JsonProtocol() for your own server instead of rosbridge:
            protocol: const RosbridgeProtocol(maxLinear: 0.5, maxAngular: 1.0),
          );
    final c = RobotController(
      transport: transport,
      config: ControlConfig(
        requireArm: _layout == Layout.drone,
        defaultAxis: const AxisConfig(deadzone: 0.08, expo: 0.3),
        axes: const {ControlAxis.surge: AxisConfig(deadzone: 0.08, expo: 0.3, slewRate: 4)},
      ),
    );
    c.connect();
    return c;
  }

  void _rebuild() {
    final old = _c;
    setState(() => _c = _build());
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _connectionDialog() async {
    final ctl = TextEditingController(text: _url);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Robot connection'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'WebSocket URL (empty = simulator)',
            hintText: 'ws://192.168.1.50:9090',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Connect')),
        ],
      ),
    );
    if (result != null) {
      _url = result;
      _rebuild();
    }
  }

  Widget _pad() {
    switch (_layout) {
      case Layout.arcade:
        return DifferentialDrivePad(controller: _c);
      case Layout.tank:
        return DifferentialDrivePad(controller: _c, style: DriveStyle.tank);
      case Layout.omni:
        return OmniDrivePad(controller: _c);
      case Layout.car:
        return CarControlPad(controller: _c);
      case Layout.drone:
        return DroneControlPad(controller: _c);
      case Layout.navigation:
        return NavigationPad(controller: _c);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        title: DropdownButton<Layout>(
          value: _layout,
          underline: const SizedBox(),
          items: [for (final l in Layout.values) DropdownMenuItem(value: l, child: Text(l.name.toUpperCase()))],
          onChanged: (l) {
            if (l == null) return;
            _layout = l;
            _rebuild();
          },
        ),
        actions: [IconButton(icon: const Icon(Icons.settings_ethernet), onPressed: _connectionDialog)],
      ),
      body: KeyboardControlInput(controller: _c, child: _pad()),
    );
  }
}

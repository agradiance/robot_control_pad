/// Degrees of freedom a pad can drive.
///
/// Conventions follow ROS REP-103 (FLU body frame):
/// * `surge`  +forward
/// * `sway`   +LEFT
/// * `heave`  +UP
/// * `yaw`    +counter-clockwise (left turn). For car-like robots this channel
///            carries the normalised steering command (+left).
/// * `roll` / `pitch` are raw attitude commands for acro-style vehicles;
///   most robots leave them at 0.
///
/// All values are normalised to -1..1.
enum ControlAxis { surge, sway, heave, roll, pitch, yaw }

class ControlCommand {
  const ControlCommand({
    this.surge = 0,
    this.sway = 0,
    this.heave = 0,
    this.roll = 0,
    this.pitch = 0,
    this.yaw = 0,
    this.buttons = const {},
    this.timestampMs = 0,
    this.sequence = 0,
  });

  final double surge, sway, heave, roll, pitch, yaw;
  final Map<String, bool> buttons;
  final int timestampMs;
  final int sequence;

  static const ControlCommand zero = ControlCommand();

  double axis(ControlAxis a) {
    switch (a) {
      case ControlAxis.surge:
        return surge;
      case ControlAxis.sway:
        return sway;
      case ControlAxis.heave:
        return heave;
      case ControlAxis.roll:
        return roll;
      case ControlAxis.pitch:
        return pitch;
      case ControlAxis.yaw:
        return yaw;
    }
  }

  bool get isNeutral =>
      surge == 0 && sway == 0 && heave == 0 && roll == 0 && pitch == 0 && yaw == 0;

  Map<String, dynamic> toJson() => {
        'seq': sequence,
        't': timestampMs,
        'surge': surge,
        'sway': sway,
        'heave': heave,
        'roll': roll,
        'pitch': pitch,
        'yaw': yaw,
        'buttons': buttons,
      };

  @override
  String toString() =>
      'ControlCommand(surge: ${surge.toStringAsFixed(2)}, sway: ${sway.toStringAsFixed(2)}, '
      'heave: ${heave.toStringAsFixed(2)}, yaw: ${yaw.toStringAsFixed(2)})';
}

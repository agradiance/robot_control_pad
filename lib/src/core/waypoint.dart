class Waypoint {
  const Waypoint(this.x, this.y, {this.theta, this.label});
  final double x, y;
  final double? theta;
  final String? label;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        if (theta != null) 'theta': theta,
        if (label != null) 'label': label,
      };
}

/// Simple occupancy grid (ROS OccupancyGrid layout): row-major, -1 unknown,
/// 0..100 occupancy probability. Origin is the world position of cell (0,0).
class OccupancyGridData {
  const OccupancyGridData({
    required this.width,
    required this.height,
    required this.resolution,
    required this.data,
    this.originX = 0,
    this.originY = 0,
  });

  final int width, height;
  final double resolution; // metres per cell
  final double originX, originY;
  final List<int> data;
}

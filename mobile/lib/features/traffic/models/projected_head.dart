/// A projected future position of a traffic target.
class ProjectedHead {
  /// How far ahead this projection is (e.g. 120s, 300s).
  final int intervalSeconds;

  final double latitude;
  final double longitude;

  /// Projected altitude in feet MSL, if available.
  final int? altitude;

  const ProjectedHead({
    required this.intervalSeconds,
    required this.latitude,
    required this.longitude,
    this.altitude,
  });
}

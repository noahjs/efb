import 'package:shared_preferences/shared_preferences.dart';

/// Configurable settings for the traffic overlay.
class TrafficSettings {
  /// Polling interval for API traffic in seconds.
  final int pollIntervalSeconds;

  /// Query radius in nautical miles.
  final double queryRadiusNm;

  /// Whether to show projected heads on the map.
  final bool showHeads;

  /// Intervals for projected heads in seconds.
  final List<int> headIntervals;

  /// Automatically switch between GDL 90 and API sources.
  final bool autoSourceSwitch;

  const TrafficSettings({
    this.pollIntervalSeconds = 10,
    this.queryRadiusNm = 30,
    this.showHeads = true,
    this.headIntervals = const [120, 300],
    this.autoSourceSwitch = true,
  });

  static Future<TrafficSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TrafficSettings(
      pollIntervalSeconds: prefs.getInt('traffic_poll_interval') ?? 10,
      queryRadiusNm: prefs.getDouble('traffic_query_radius') ?? 30,
      showHeads: prefs.getBool('traffic_show_heads') ?? true,
      autoSourceSwitch: prefs.getBool('traffic_auto_source') ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('traffic_poll_interval', pollIntervalSeconds);
    await prefs.setDouble('traffic_query_radius', queryRadiusNm);
    await prefs.setBool('traffic_show_heads', showHeads);
    await prefs.setBool('traffic_auto_source', autoSourceSwitch);
  }

  TrafficSettings copyWith({
    int? pollIntervalSeconds,
    double? queryRadiusNm,
    bool? showHeads,
    List<int>? headIntervals,
    bool? autoSourceSwitch,
  }) {
    return TrafficSettings(
      pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
      queryRadiusNm: queryRadiusNm ?? this.queryRadiusNm,
      showHeads: showHeads ?? this.showHeads,
      headIntervals: headIntervals ?? this.headIntervals,
      autoSourceSwitch: autoSourceSwitch ?? this.autoSourceSwitch,
    );
  }
}

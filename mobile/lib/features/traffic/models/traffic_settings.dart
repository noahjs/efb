import 'package:shared_preferences/shared_preferences.dart';

/// Projected head display style.
enum HeadStyle {
  /// 60-second leader line only, no bubbles.
  line60s,

  /// 2-minute and 5-minute dots with leader lines.
  bubbles2m5m,
}

/// Altitude filter options for traffic display.
enum AltitudeFilter {
  all,
  within1000,
  within3000,
  within5000,
  belowFL180,
  aboveFL180,
}

/// Configurable settings for the traffic overlay.
class TrafficSettings {
  /// Polling interval for API traffic in seconds.
  final int pollIntervalSeconds;

  /// Query radius in nautical miles.
  final double queryRadiusNm;

  /// Whether to show projected heads on the map.
  final bool showHeads;

  /// Display style for projected heads.
  final HeadStyle headStyle;

  /// Intervals for projected heads in seconds (derived from headStyle).
  List<int> get headIntervals => switch (headStyle) {
        HeadStyle.line60s => const [60],
        HeadStyle.bubbles2m5m => const [120, 300],
      };

  /// Automatically switch between GDL 90 and API sources.
  final bool autoSourceSwitch;

  /// Whether to show callsign/hex labels on traffic targets.
  final bool showLabels;

  /// Whether to hide ground traffic (not airborne or altitude == 0).
  final bool hideGround;

  /// Altitude filter for displayed traffic.
  final AltitudeFilter altitudeFilter;

  /// Whether to show proximity alert banners.
  final bool proximityAlerts;

  const TrafficSettings({
    this.pollIntervalSeconds = 10,
    this.queryRadiusNm = 30,
    this.showHeads = true,
    this.headStyle = HeadStyle.bubbles2m5m,
    this.autoSourceSwitch = true,
    this.showLabels = true,
    this.hideGround = true,
    this.altitudeFilter = AltitudeFilter.all,
    this.proximityAlerts = true,
  });

  static Future<TrafficSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final filterIndex = prefs.getInt('traffic_altitude_filter') ?? 0;
    final headStyleIndex = prefs.getInt('traffic_head_style') ?? 1;
    return TrafficSettings(
      pollIntervalSeconds: prefs.getInt('traffic_poll_interval') ?? 10,
      queryRadiusNm: prefs.getDouble('traffic_query_radius') ?? 30,
      showHeads: prefs.getBool('traffic_show_heads') ?? true,
      headStyle: headStyleIndex < HeadStyle.values.length
          ? HeadStyle.values[headStyleIndex]
          : HeadStyle.bubbles2m5m,
      autoSourceSwitch: prefs.getBool('traffic_auto_source') ?? true,
      showLabels: prefs.getBool('traffic_show_labels') ?? true,
      hideGround: prefs.getBool('traffic_hide_ground') ?? true,
      altitudeFilter: filterIndex < AltitudeFilter.values.length
          ? AltitudeFilter.values[filterIndex]
          : AltitudeFilter.all,
      proximityAlerts: prefs.getBool('traffic_proximity_alerts') ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('traffic_poll_interval', pollIntervalSeconds);
    await prefs.setDouble('traffic_query_radius', queryRadiusNm);
    await prefs.setBool('traffic_show_heads', showHeads);
    await prefs.setInt('traffic_head_style', headStyle.index);
    await prefs.setBool('traffic_auto_source', autoSourceSwitch);
    await prefs.setBool('traffic_show_labels', showLabels);
    await prefs.setBool('traffic_hide_ground', hideGround);
    await prefs.setInt('traffic_altitude_filter', altitudeFilter.index);
    await prefs.setBool('traffic_proximity_alerts', proximityAlerts);
  }

  TrafficSettings copyWith({
    int? pollIntervalSeconds,
    double? queryRadiusNm,
    bool? showHeads,
    HeadStyle? headStyle,
    bool? autoSourceSwitch,
    bool? showLabels,
    bool? hideGround,
    AltitudeFilter? altitudeFilter,
    bool? proximityAlerts,
  }) {
    return TrafficSettings(
      pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
      queryRadiusNm: queryRadiusNm ?? this.queryRadiusNm,
      showHeads: showHeads ?? this.showHeads,
      headStyle: headStyle ?? this.headStyle,
      autoSourceSwitch: autoSourceSwitch ?? this.autoSourceSwitch,
      showLabels: showLabels ?? this.showLabels,
      hideGround: hideGround ?? this.hideGround,
      altitudeFilter: altitudeFilter ?? this.altitudeFilter,
      proximityAlerts: proximityAlerts ?? this.proximityAlerts,
    );
  }
}

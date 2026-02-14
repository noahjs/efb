import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../traffic/models/traffic_settings.dart';
import '../layers/map_layer_def.dart';
import '../layers/map_layer_registry.dart';
import '../widgets/aeronautical_settings_panel.dart';

/// Immutable snapshot of all map layer state.
class MapLayerState {
  final MapLayerId baseLayer;
  final Set<MapLayerId> activeOverlays;
  final AeroSettings aeroSettings;
  final TrafficSettings trafficSettings;
  final int windsAloftAltitude;
  final int radarFrameIndex;
  final int cloudsAltitude; // pressure level in hPa, default 850

  const MapLayerState({
    this.baseLayer = MapLayerId.dark,
    this.activeOverlays = const {MapLayerId.flightCategory},
    this.aeroSettings = const AeroSettings(),
    this.trafficSettings = const TrafficSettings(),
    this.windsAloftAltitude = 9000,
    this.radarFrameIndex = 10,
    this.cloudsAltitude = 850,
  });

  MapLayerState copyWith({
    MapLayerId? baseLayer,
    Set<MapLayerId>? activeOverlays,
    AeroSettings? aeroSettings,
    TrafficSettings? trafficSettings,
    int? windsAloftAltitude,
    int? radarFrameIndex,
    int? cloudsAltitude,
  }) {
    return MapLayerState(
      baseLayer: baseLayer ?? this.baseLayer,
      activeOverlays: activeOverlays ?? this.activeOverlays,
      aeroSettings: aeroSettings ?? this.aeroSettings,
      trafficSettings: trafficSettings ?? this.trafficSettings,
      windsAloftAltitude: windsAloftAltitude ?? this.windsAloftAltitude,
      radarFrameIndex: radarFrameIndex ?? this.radarFrameIndex,
      cloudsAltitude: cloudsAltitude ?? this.cloudsAltitude,
    );
  }

  /// Whether a given overlay layer is currently active.
  bool isActive(MapLayerId id) => activeOverlays.contains(id);
}

class MapLayerStateNotifier extends AsyncNotifier<MapLayerState> {
  @override
  Future<MapLayerState> build() async {
    final prefs = await SharedPreferences.getInstance();

    // Base layer
    final baseKey = prefs.getString('map_base_layer') ?? 'dark';
    final baseDef = kLayerBySourceKey[baseKey];
    final baseLayer = baseDef?.id ?? MapLayerId.dark;

    // Active overlays
    final overlayKeys =
        prefs.getStringList('map_overlays') ?? ['flight_category'];
    final overlays = <MapLayerId>{};
    for (final key in overlayKeys) {
      final def = kLayerBySourceKey[key];
      if (def != null) overlays.add(def.id);
    }

    // Aero & traffic settings (use their own persistence)
    final aero = await AeroSettings.load();
    final traffic = await TrafficSettings.load();

    return MapLayerState(
      baseLayer: baseLayer,
      activeOverlays: overlays,
      aeroSettings: aero,
      trafficSettings: traffic,
    );
  }

  // ── Base layer ──────────────────────────────────────────────────────────

  void setBaseLayer(MapLayerId id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(baseLayer: id));
    _persist();
  }

  // ── Overlay toggles ─────────────────────────────────────────────────────

  void toggleOverlay(MapLayerId id) {
    final current = state.value;
    if (current == null) return;

    final next = Set<MapLayerId>.from(current.activeOverlays);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      // Enforce exclusive groups: turning one on turns others off
      final def = kLayerById[id];
      if (def?.exclusiveGroup != null) {
        final group = kExclusiveGroups[def!.exclusiveGroup!] ?? {};
        next.removeAll(group);
      }
      next.add(id);
    }

    state = AsyncData(current.copyWith(activeOverlays: next));
    _persist();
  }

  // ── Aero settings ───────────────────────────────────────────────────────

  void setAeroSettings(AeroSettings settings) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(aeroSettings: settings));
    settings.save();
  }

  // ── Traffic settings ────────────────────────────────────────────────────

  void setTrafficSettings(TrafficSettings settings) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(trafficSettings: settings));
    settings.save();
  }

  // ── Winds aloft altitude ────────────────────────────────────────────────

  void setWindsAloftAltitude(int altitude) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(windsAloftAltitude: altitude));
  }

  // ── Clouds altitude (pressure level) ────────────────────────────────

  void setCloudsAltitude(int level) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(cloudsAltitude: level));
  }

  // ── Radar frame ───────────────────────────────────────────────────────

  void setRadarFrame(int index) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(radarFrameIndex: index));
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> _persist() async {
    final current = state.value;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    final baseDef = kLayerById[current.baseLayer];
    if (baseDef != null) {
      prefs.setString('map_base_layer', baseDef.sourceKey);
    }
    prefs.setStringList(
      'map_overlays',
      current.activeOverlays
          .map((id) => kLayerById[id]?.sourceKey)
          .whereType<String>()
          .toList(),
    );
    current.aeroSettings.save();
  }
}

final mapLayerStateProvider =
    AsyncNotifierProvider<MapLayerStateNotifier, MapLayerState>(
        MapLayerStateNotifier.new);

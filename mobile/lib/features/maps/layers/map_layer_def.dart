/// Canonical identifiers for every map layer.
///
/// Adding a new layer starts here — add an enum value, then register it in
/// [map_layer_registry.dart].
enum MapLayerId {
  // Base layers (mutually exclusive)
  dark,
  vfr,
  satellite,
  street,

  // Overlays
  aeronautical,
  flightCategory,
  traffic,
  tfrs,
  airSigmet,
  pireps,

  // Exclusive weather-derived group (only one active at a time)
  surfaceWind,
  windsAloft,
  temperature,
  visibility,
  ceiling,
}

/// Which column/section a layer belongs to in the LayerPicker UI.
enum LayerGroup {
  /// Mutually-exclusive base map styles (Dark, VFR, Satellite, Street).
  baseLayer,

  /// Left column overlays (currently just Aeronautical).
  leftOverlay,

  /// Right column overlays (all other toggleable layers).
  rightOverlay,
}

/// Metadata for one map layer.
///
/// Instances are const and live in [kMapLayers] (see map_layer_registry.dart).
class MapLayerDef {
  final MapLayerId id;
  final String displayName;
  final LayerGroup group;

  /// Layers sharing an [exclusiveGroup] are mutually exclusive — enabling one
  /// disables the others in the same group.  `null` means no exclusivity.
  final String? exclusiveGroup;

  /// When true the layer's data provider needs the current map bounds.
  final bool needsBounds;

  const MapLayerDef({
    required this.id,
    required this.displayName,
    required this.group,
    this.exclusiveGroup,
    this.needsBounds = false,
  });

  /// The string key used in the `overlays` map passed to EfbMapView,
  /// in SharedPreferences persistence, and in platform layer registries.
  ///
  /// Derived deterministically from the enum name using the same kebab-case
  /// convention already established (e.g. `airSigmet` → `'air_sigmet'`).
  String get sourceKey {
    switch (id) {
      case MapLayerId.dark: return 'dark';
      case MapLayerId.vfr: return 'vfr';
      case MapLayerId.satellite: return 'satellite';
      case MapLayerId.street: return 'street';
      case MapLayerId.aeronautical: return 'aeronautical';
      case MapLayerId.flightCategory: return 'flight_category';
      case MapLayerId.traffic: return 'traffic';
      case MapLayerId.tfrs: return 'tfrs';
      case MapLayerId.airSigmet: return 'air_sigmet';
      case MapLayerId.pireps: return 'pireps';
      case MapLayerId.surfaceWind: return 'surface_wind';
      case MapLayerId.windsAloft: return 'winds_aloft';
      case MapLayerId.temperature: return 'temperature';
      case MapLayerId.visibility: return 'visibility';
      case MapLayerId.ceiling: return 'ceiling';
    }
  }
}

import 'map_layer_def.dart';

/// Master list of all map layers.  Order here determines display order in
/// the LayerPicker UI.
const kMapLayers = <MapLayerDef>[
  // ── Base layers ──────────────────────────────────────────────────────
  MapLayerDef(
    id: MapLayerId.dark,
    displayName: 'Dark',
    group: LayerGroup.baseLayer,
  ),
  MapLayerDef(
    id: MapLayerId.vfr,
    displayName: 'VFR Sectional',
    group: LayerGroup.baseLayer,
  ),
  MapLayerDef(
    id: MapLayerId.satellite,
    displayName: 'Satellite',
    group: LayerGroup.baseLayer,
  ),
  MapLayerDef(
    id: MapLayerId.street,
    displayName: 'Street',
    group: LayerGroup.baseLayer,
  ),

  // ── Left overlay column ──────────────────────────────────────────────
  MapLayerDef(
    id: MapLayerId.aeronautical,
    displayName: 'Aeronautical',
    group: LayerGroup.leftOverlay,
    needsBounds: true,
  ),

  // ── Right overlay column ─────────────────────────────────────────────
  MapLayerDef(
    id: MapLayerId.flightCategory,
    displayName: 'Flight Category',
    group: LayerGroup.rightOverlay,
    needsBounds: true,
  ),
  MapLayerDef(
    id: MapLayerId.traffic,
    displayName: 'Traffic',
    group: LayerGroup.rightOverlay,
  ),
  MapLayerDef(
    id: MapLayerId.tfrs,
    displayName: 'TFRs',
    group: LayerGroup.rightOverlay,
  ),
  MapLayerDef(
    id: MapLayerId.airSigmet,
    displayName: 'AIR/SIGMET/CWAs',
    group: LayerGroup.rightOverlay,
  ),
  MapLayerDef(
    id: MapLayerId.pireps,
    displayName: 'PIREPs',
    group: LayerGroup.rightOverlay,
    needsBounds: true,
  ),

  MapLayerDef(
    id: MapLayerId.radar,
    displayName: 'Radar',
    group: LayerGroup.rightOverlay,
  ),

  // Xweather raster tile overlays
  MapLayerDef(
    id: MapLayerId.satelliteGeocolor,
    displayName: 'Satellite (GeoColor)',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'xw_satellite',
  ),
  MapLayerDef(
    id: MapLayerId.satelliteIr,
    displayName: 'Satellite (IR)',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'xw_satellite',
  ),
  MapLayerDef(
    id: MapLayerId.satelliteVisible,
    displayName: 'Satellite (Visible)',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'xw_satellite',
  ),
  MapLayerDef(
    id: MapLayerId.lightning,
    displayName: 'Lightning',
    group: LayerGroup.rightOverlay,
  ),
  MapLayerDef(
    id: MapLayerId.weatherAlerts,
    displayName: 'Weather Alerts',
    group: LayerGroup.rightOverlay,
  ),
  MapLayerDef(
    id: MapLayerId.stormCells,
    displayName: 'Storm Cells',
    group: LayerGroup.rightOverlay,
  ),
  MapLayerDef(
    id: MapLayerId.forecastRadar,
    displayName: 'Forecast Radar',
    group: LayerGroup.rightOverlay,
  ),

  // Weather-derived (mutually exclusive)
  MapLayerDef(
    id: MapLayerId.surfaceWind,
    displayName: 'Surface Wind',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'weather_derived',
    needsBounds: true,
  ),
  MapLayerDef(
    id: MapLayerId.windsAloft,
    displayName: 'Winds Aloft',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'weather_derived',
    needsBounds: true,
  ),
  MapLayerDef(
    id: MapLayerId.temperature,
    displayName: 'Temperature',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'weather_derived',
    needsBounds: true,
  ),
  MapLayerDef(
    id: MapLayerId.visibility,
    displayName: 'Visibility',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'weather_derived',
    needsBounds: true,
  ),
  MapLayerDef(
    id: MapLayerId.ceiling,
    displayName: 'Ceiling',
    group: LayerGroup.rightOverlay,
    exclusiveGroup: 'weather_derived',
    needsBounds: true,
  ),
];

// ── Derived lookup helpers ──────────────────────────────────────────────────

/// Quick enum → definition lookup.
final Map<MapLayerId, MapLayerDef> kLayerById = {
  for (final def in kMapLayers) def.id: def,
};

/// Quick sourceKey → definition lookup.
final Map<String, MapLayerDef> kLayerBySourceKey = {
  for (final def in kMapLayers) def.sourceKey: def,
};

/// Base layer definitions (left column, radio-select).
final List<MapLayerDef> kBaseLayers =
    kMapLayers.where((d) => d.group == LayerGroup.baseLayer).toList();

/// Left-column overlay definitions.
final List<MapLayerDef> kLeftOverlays =
    kMapLayers.where((d) => d.group == LayerGroup.leftOverlay).toList();

/// Right-column overlay definitions.
final List<MapLayerDef> kRightOverlays =
    kMapLayers.where((d) => d.group == LayerGroup.rightOverlay).toList();

/// Sets of layer IDs sharing an exclusive group.
final Map<String, Set<MapLayerId>> kExclusiveGroups = () {
  final map = <String, Set<MapLayerId>>{};
  for (final def in kMapLayers) {
    if (def.exclusiveGroup != null) {
      map.putIfAbsent(def.exclusiveGroup!, () => {}).add(def.id);
    }
  }
  return map;
}();

/// Xweather raster tile layer names — single source of truth for the API
/// layer name used in tile URLs.
const kXweatherLayerNames = <MapLayerId, String>{
  MapLayerId.satelliteGeocolor: 'satellite-geocolor',
  MapLayerId.satelliteIr: 'satellite-infrared-color',
  MapLayerId.satelliteVisible: 'satellite-visible',
  MapLayerId.forecastRadar: 'fradar',
};

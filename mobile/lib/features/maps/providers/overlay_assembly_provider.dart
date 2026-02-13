import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layers/map_layer_registry.dart';
import 'breadcrumb_provider.dart';
import 'layer_data_providers.dart';

/// Assembles the final `overlays` map for EfbMapView by combining all active
/// layer data providers.
///
/// Each layer provider internally checks whether its layer is active (via
/// [mapLayerStateProvider]) and returns null when inactive, so this provider
/// simply collects non-null results into the map.
final assembledOverlaysProvider =
    Provider<Map<String, Map<String, dynamic>?>>((ref) {
  final overlays = <String, Map<String, dynamic>?>{};

  // Aeronautical sub-layers
  final airspaces = ref.watch(airspaceOverlayProvider);
  if (airspaces != null) overlays['airspaces'] = airspaces;

  final airways = ref.watch(airwayOverlayProvider);
  if (airways != null) overlays['airways'] = airways;

  final artcc = ref.watch(artccOverlayProvider);
  if (artcc != null) overlays['artcc'] = artcc;

  final navaids = ref.watch(navaidOverlayProvider);
  if (navaids != null) overlays['navaids'] = navaids;

  final fixes = ref.watch(fixOverlayProvider);
  if (fixes != null) overlays['fixes'] = fixes;

  // Weather / situational overlays
  final tfrs = ref.watch(tfrOverlayProvider);
  if (tfrs != null) overlays['tfrs'] = tfrs;

  final advisories = ref.watch(advisoryOverlayProvider);
  if (advisories != null) overlays['advisories'] = advisories;

  final pireps = ref.watch(pirepOverlayProvider);
  if (pireps != null) overlays['pireps'] = pireps;

  final metarOverlay = ref.watch(metarOverlayProvider);
  if (metarOverlay != null) overlays['metar-overlay'] = metarOverlay;

  // Vector weather overlays
  final stormCells = ref.watch(stormCellOverlayProvider);
  if (stormCells != null) overlays['storm_cells'] = stormCells;

  final lightning = ref.watch(lightningOverlayProvider);
  if (lightning != null) overlays['lightning'] = lightning;

  final weatherAlerts = ref.watch(weatherAlertOverlayProvider);
  if (weatherAlerts != null) overlays['weather_alerts'] = weatherAlerts;

  final radar = ref.watch(radarOverlayProvider);
  if (radar != null) overlays['radar'] = radar;

  // Xweather raster tile overlays
  for (final id in kXweatherLayerNames.keys) {
    final xw = ref.watch(xweatherOverlayProvider(id));
    if (xw != null) {
      final def = kLayerById[id]!;
      overlays[def.sourceKey] = xw;
    }
  }

  final windsAloft = ref.watch(windsAloftOverlayProvider);
  if (windsAloft != null) overlays['winds-aloft'] = windsAloft;

  final traffic = ref.watch(trafficOverlayProvider);
  if (traffic != null) overlays['traffic'] = traffic;

  // Always-on overlays
  final breadcrumb = ref.watch(breadcrumbGeoJsonProvider);
  if (breadcrumb != null) overlays['breadcrumb'] = breadcrumb;

  final ownPosition = ref.watch(ownPositionOverlayProvider);
  if (ownPosition != null) overlays['own-position'] = ownPosition;

  return overlays;
});

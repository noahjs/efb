import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/airport_providers.dart';
import '../../../services/aeronautical_providers.dart';
import '../../../services/windy_providers.dart';
import '../../adsb/providers/adsb_providers.dart';
import '../../imagery/imagery_providers.dart';
import '../../traffic/providers/traffic_providers.dart';
import '../layers/map_layer_def.dart';
import '../layers/geojson_enrichment.dart';
import '../widgets/map_view.dart';
import 'map_layer_state_provider.dart';

/// Current visible map bounds, updated by MapsScreen on pan/zoom.
class MapBoundsNotifier extends Notifier<MapBounds?> {
  @override
  MapBounds? build() => null;
  void set(MapBounds? bounds) => state = bounds;
}

final mapBoundsProvider =
    NotifierProvider<MapBoundsNotifier, MapBounds?>(MapBoundsNotifier.new);

// ── TFR overlay ─────────────────────────────────────────────────────────────

final tfrOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(MapLayerId.tfrs)) return null;
  return ref.watch(tfrsProvider).value;
});

// ── Advisory (AIR/SIGMET/CWA) overlay ───────────────────────────────────────

final advisoryOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(MapLayerId.airSigmet)) {
    return null;
  }

  final gairmets =
      ref.watch(advisoriesProvider(const AdvisoryParams(type: 'gairmets'))).value;
  final sigmets =
      ref.watch(advisoriesProvider(const AdvisoryParams(type: 'sigmets'))).value;
  final cwas =
      ref.watch(advisoriesProvider(const AdvisoryParams(type: 'cwas'))).value;

  final allFeatures = <dynamic>[
    ...?extractFeatures(gairmets),
    ...?extractFeatures(sigmets),
    ...?extractFeatures(cwas),
  ];
  if (allFeatures.isEmpty) return null;
  return enrichAdvisoryGeoJson({
    'type': 'FeatureCollection',
    'features': allFeatures,
  });
});

// ── PIREP overlay ───────────────────────────────────────────────────────────

final pirepOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || !layerState.isActive(MapLayerId.pireps) || bounds == null) {
    return null;
  }
  final bbox = '${bounds.minLat},${bounds.minLng},'
      '${bounds.maxLat},${bounds.maxLng}';
  final data = ref.watch(mapPirepsProvider(bbox)).value;
  if (data == null) return null;
  return enrichPirepGeoJson(data);
});

// ── METAR overlay (surface wind / temperature / visibility / ceiling) ───────

final metarOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || bounds == null) return null;

  const metarTypes = {
    MapLayerId.surfaceWind,
    MapLayerId.temperature,
    MapLayerId.visibility,
    MapLayerId.ceiling,
  };
  final active = layerState.activeOverlays.intersection(metarTypes);
  if (active.isEmpty) return null;

  final metars = ref.watch(mapMetarsProvider(bounds)).value;
  if (metars == null) return null;

  // Map the enum back to the overlay type string used by buildMetarOverlayGeoJson
  final overlayType = switch (active.first) {
    MapLayerId.surfaceWind => 'surface_wind',
    MapLayerId.temperature => 'temperature',
    MapLayerId.visibility => 'visibility',
    MapLayerId.ceiling => 'ceiling',
    _ => 'surface_wind',
  };
  return buildMetarOverlayGeoJson(metars, overlayType);
});

// ── Winds aloft overlay ─────────────────────────────────────────────────────

final windsAloftOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || !layerState.isActive(MapLayerId.windsAloft) || bounds == null) {
    return null;
  }
  final windParams = WindGridParams(
    bounds: bounds,
    altitude: layerState.windsAloftAltitude,
  );
  return ref.watch(windGridProvider(windParams)).value;
});

// ── Radar overlay (activation sentinel + frame index) ───────────────────

final radarOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(MapLayerId.radar)) return null;
  return {'frameIndex': layerState.radarFrameIndex};
});

// ── Storm Cell overlay ──────────────────────────────────────────────────────

final stormCellOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(MapLayerId.stormCells)) return null;
  final data = ref.watch(stormCellsProvider).value;
  if (data == null) return null;
  return enrichStormCellGeoJson(data);
});

// ── Lightning overlay ───────────────────────────────────────────────────────

final lightningOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(MapLayerId.lightning)) return null;
  final data = ref.watch(lightningThreatsProvider).value;
  if (data == null) return null;
  return enrichLightningGeoJson(data);
});

// ── Weather Alert overlay ───────────────────────────────────────────────────

final weatherAlertOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(MapLayerId.weatherAlerts)) return null;
  final data = ref.watch(weatherAlertsProvider).value;
  if (data == null) return null;
  return enrichWeatherAlertGeoJson(data);
});

// ── Xweather raster tile overlays (activation sentinel) ─────────────────

final xweatherOverlayProvider =
    Provider.family<Map<String, dynamic>?, MapLayerId>((ref, id) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(id)) return null;
  return const {'active': true};
});

// ── Traffic overlay ─────────────────────────────────────────────────────────

final trafficOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  if (layerState == null || !layerState.isActive(MapLayerId.traffic)) return null;
  return ref.watch(trafficGeoJsonProvider);
});

// ── Own-position overlay (always on when GPS available) ─────────────────────

final ownPositionOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final pos = ref.watch(activePositionProvider);
  if (pos == null) return null;
  return {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [pos.longitude, pos.latitude],
        },
        'properties': {
          'groundspeed': pos.groundspeed,
          'track': pos.track,
        },
      },
    ],
  };
});

// ── Aeronautical sub-layers ─────────────────────────────────────────────────

final airspaceOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || bounds == null) return null;
  if (!layerState.isActive(MapLayerId.aeronautical)) return null;
  if (!layerState.aeroSettings.showAirspaces) return null;

  final classes = <String>['B', 'C', 'D'];
  if (layerState.aeroSettings.showClassE) classes.add('E');

  return ref
      .watch(mapAirspacesProvider((
        minLat: bounds.minLat,
        maxLat: bounds.maxLat,
        minLng: bounds.minLng,
        maxLng: bounds.maxLng,
        classes: classes.join(','),
      )))
      .value;
});

final airwayOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || bounds == null) return null;
  if (!layerState.isActive(MapLayerId.aeronautical)) return null;
  if (!layerState.aeroSettings.showAirways) return null;

  final types = <String>[];
  if (layerState.aeroSettings.showLowAirways) types.addAll(['V', 'T']);
  if (layerState.aeroSettings.showHighAirways) types.addAll(['J', 'Q']);
  final typesStr = types.isNotEmpty ? types.join(',') : null;

  return ref
      .watch(mapAirwaysProvider((
        minLat: bounds.minLat,
        maxLat: bounds.maxLat,
        minLng: bounds.minLng,
        maxLng: bounds.maxLng,
        types: typesStr,
      )))
      .value;
});

final artccOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || bounds == null) return null;
  if (!layerState.isActive(MapLayerId.aeronautical)) return null;
  if (!layerState.aeroSettings.showArtcc) return null;

  return ref.watch(mapArtccProvider(bounds)).value;
});

final navaidOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || bounds == null) return null;
  if (!layerState.isActive(MapLayerId.aeronautical)) return null;
  if (!layerState.aeroSettings.showNavaids) return null;

  final navaids = ref.watch(mapNavaidsProvider(bounds)).value;
  if (navaids == null) return null;
  return navaidsToGeoJson(navaids);
});

final fixOverlayProvider = Provider<Map<String, dynamic>?>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);
  if (layerState == null || bounds == null) return null;
  if (!layerState.isActive(MapLayerId.aeronautical)) return null;
  if (!layerState.aeroSettings.showFixes) return null;

  final fixes = ref.watch(mapFixesProvider(bounds)).value;
  if (fixes == null) return null;
  return fixesToGeoJson(fixes);
});

// ── Airport list (with flight category merge + weather stations) ────────────

/// Result of building the airports list with merged METAR data.
class AirportListResult {
  final List<Map<String, dynamic>> airports;
  final Map<String, Map<String, dynamic>> weatherStations;

  const AirportListResult({
    required this.airports,
    required this.weatherStations,
  });
}

final airportListProvider = Provider<AirportListResult>((ref) {
  final layerState = ref.watch(mapLayerStateProvider).value;
  final bounds = ref.watch(mapBoundsProvider);

  if (layerState == null) {
    return const AirportListResult(airports: [], weatherStations: {});
  }

  final showAeronautical = layerState.isActive(MapLayerId.aeronautical);
  final showFlightCategory = layerState.isActive(MapLayerId.flightCategory);
  final aero = layerState.aeroSettings;

  var airports = <Map<String, dynamic>>[];

  // Fetch airports when aeronautical overlay or flight category is active
  if ((showAeronautical && aero.showAirports || showFlightCategory) && bounds != null) {
    final airportsAsync = ref.watch(mapAirportsProvider(bounds));
    airports = airportsAsync.value
            ?.cast<Map<String, dynamic>>()
            .toList() ??
        [];

    // Granular airport filtering
    airports = airports.where((a) {
      final type = a['facility_type'] ?? '';
      final use = a['facility_use'] ?? '';
      if (type == 'H' && !aero.showHeliports) return false;
      if (type == 'S' && !aero.showSeaplaneBases) return false;
      if (['G', 'U', 'B'].contains(type) && !aero.showOtherFields) return false;
      if (use == 'PR' && !aero.showPrivateAirports) return false;
      return true;
    }).toList();
  }

  final wxStations = <String, Map<String, dynamic>>{};

  // Merge flight category data
  if (showFlightCategory && bounds != null) {
    final metarsAsync = ref.watch(mapMetarsProvider(bounds));
    final metars = metarsAsync.value;
    if (metars != null) {
      final metarMap = <String, Map<dynamic, dynamic>>{};
      for (final m in metars) {
        if (m is Map) {
          final icao = m['icaoId'] as String?;
          if (icao != null) metarMap[icao] = m;
        }
      }
      debugPrint(
          '[EFB] Flight category: ${metarMap.length} unique METARs, ${airports.length} airports in list');

      final matched = <String>{};
      airports = airports.map((a) {
        final icao = a['icao_identifier'] ?? a['identifier'] ?? '';
        final metar = metarMap[icao.toString()];
        if (metar != null) {
          matched.add(icao.toString());
          final cat = metar['fltCat'] as String?;
          if (cat != null) return {...a, 'category': cat};
        }
        return a;
      }).toList();
      debugPrint(
          '[EFB] Matched ${matched.length} airports to METARs, ${metarMap.length - matched.length} unmatched');

      // Add METAR stations not in airports list
      for (final entry in metarMap.entries) {
        if (matched.contains(entry.key)) continue;
        final m = entry.value;
        final lat = m['lat'] as num?;
        final lon = m['lon'] as num?;
        final cat = m['fltCat'] as String?;
        if (lat == null || lon == null || cat == null) continue;
        final wxEntry = {
          'identifier': entry.key,
          'icao_identifier': entry.key,
          'latitude': lat.toDouble(),
          'longitude': lon.toDouble(),
          'category': cat,
          'isWeatherStation': true,
          '_metarData': m,
        };
        airports.add(wxEntry);
        wxStations[entry.key] = wxEntry;
      }
      debugPrint(
          '[EFB] ${wxStations.length} wx stations added as dots, total airports now: ${airports.length}');
    }
  }

  return AirportListResult(airports: airports, weatherStations: wxStations);
});

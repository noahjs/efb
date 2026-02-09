import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../maps/widgets/map_view.dart' show mapboxAccessToken;

/// Native (iOS/Android) advisory map using mapbox_maps_flutter.
class AdvisoryMap extends StatefulWidget {
  final Map<String, dynamic> geojson;
  final ValueChanged<List<Map<String, dynamic>>>? onFeaturesTapped;

  const AdvisoryMap({
    super.key,
    required this.geojson,
    this.onFeaturesTapped,
  });

  @override
  State<AdvisoryMap> createState() => _AdvisoryMapState();
}

class _AdvisoryMapState extends State<AdvisoryMap> {
  MapboxMap? _map;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  void _onMapCreated(MapboxMap map) {
    _map = map;
    map.setOnMapTapListener(_onMapTap);
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    final map = _map;
    if (map == null) return;

    final enriched = enrichGeoJson(widget.geojson);
    final geojsonStr = jsonEncode(enriched);

    try {
      await map.style.addSource(
        GeoJsonSource(id: 'advisories', data: geojsonStr),
      );

      // Filled polygons for area hazards
      await map.style.addLayer(FillLayer(
        id: 'advisory-fill',
        sourceId: 'advisories',
        fillColor: const Color(0xFFB0B4BC).toARGB32(),
        fillOpacity: 0.15,
        filter: ['==', ['geometry-type'], 'Polygon'],
      ));

      // Override fill-color with data-driven expression
      await map.style.setStyleLayerProperty(
        'advisory-fill',
        'fill-color',
        ['get', 'color'],
      );

      // Polygon outlines
      await map.style.addLayer(LineLayer(
        id: 'advisory-outline',
        sourceId: 'advisories',
        lineColor: const Color(0xFFB0B4BC).toARGB32(),
        lineWidth: 2.0,
        filter: ['==', ['geometry-type'], 'Polygon'],
      ));

      await map.style.setStyleLayerProperty(
        'advisory-outline',
        'line-color',
        ['get', 'color'],
      );

      // LineString features (FZLVL contours) — dashed
      await map.style.addLayer(LineLayer(
        id: 'advisory-line',
        sourceId: 'advisories',
        lineColor: const Color(0xFFB0B4BC).toARGB32(),
        lineWidth: 2.0,
        lineDasharray: [5.0, 3.0],
        filter: ['==', ['geometry-type'], 'LineString'],
      ));

      await map.style.setStyleLayerProperty(
        'advisory-line',
        'line-color',
        ['get', 'color'],
      );
    } catch (e) {
      debugPrint('Failed to add advisory layers: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;

    final point = context.touchPosition;
    final screenCoord = ScreenCoordinate(x: point.x, y: point.y);

    try {
      final results = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
        RenderedQueryOptions(
          layerIds: ['advisory-fill', 'advisory-outline', 'advisory-line'],
        ),
      );

      if (results.isNotEmpty) {
        final seen = <String>{};
        final allProps = <Map<String, dynamic>>[];
        for (final result in results) {
          if (result == null) continue;
          final props = result.queriedFeature.feature['properties'];
          if (props is Map) {
            final m = Map<String, dynamic>.from(props);
            // Deduplicate — fill + outline return the same feature twice
            final key = '${m['hazard']}|${m['tag'] ?? m['seriesId'] ?? m['cwsu'] ?? ''}|${m['validTime'] ?? m['validTimeFrom'] ?? ''}';
            if (seen.add(key)) allProps.add(m);
          }
        }
        if (allProps.isNotEmpty) {
          widget.onFeaturesTapped?.call(allProps);
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to query advisory feature: $e');
    }

    // Tapped empty area
    widget.onFeaturesTapped?.call([]);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('advisory-map'),
      styleUri: MapboxStyles.DARK,
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(-98.0, 39.0)),
        zoom: 3.5,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}

/// Enrich GeoJSON features with a `color` property based on hazard type.
/// Shared between native and web implementations.
Map<String, dynamic> enrichGeoJson(Map<String, dynamic> original) {
  final features = (original['features'] as List<dynamic>?) ?? [];
  final enrichedFeatures = features.map((f) {
    final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
    final props =
        Map<String, dynamic>.from(feature['properties'] as Map? ?? {});

    final hazard = (props['hazard'] as String? ?? '').toUpperCase();
    props['color'] = hazardColorHex(hazard);

    feature['properties'] = props;
    return feature;
  }).toList();

  return {
    'type': 'FeatureCollection',
    'features': enrichedFeatures,
  };
}

/// Map hazard type to hex color string for Mapbox data-driven styling.
String hazardColorHex(String hazard) {
  switch (hazard.toUpperCase()) {
    case 'IFR':
      return '#1E90FF';
    case 'MTN_OBSC':
    case 'MT_OBSC':
      return '#8D6E63';
    case 'TURB':
    case 'TURB-HI':
    case 'TURB-LO':
      return '#FFC107';
    case 'ICE':
      return '#00BCD4';
    case 'FZLVL':
    case 'M_FZLVL':
      return '#00BCD4';
    case 'LLWS':
      return '#FF5252';
    case 'SFC_WND':
      return '#FF9800';
    case 'CONV':
      return '#FF5252';
    default:
      return '#B0B4BC';
  }
}

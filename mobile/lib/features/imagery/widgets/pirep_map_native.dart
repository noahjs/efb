import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../maps/widgets/map_view.dart' show mapboxAccessToken;

/// Native (iOS/Android) PIREP map using mapbox_maps_flutter.
class PirepMap extends StatefulWidget {
  final Map<String, dynamic> geojson;
  final ValueChanged<Map<String, dynamic>>? onFeatureTapped;

  const PirepMap({
    super.key,
    required this.geojson,
    this.onFeatureTapped,
  });

  @override
  State<PirepMap> createState() => _PirepMapState();
}

class _PirepMapState extends State<PirepMap> {
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

    final enriched = _enrichGeoJson(widget.geojson);
    final geojsonStr = jsonEncode(enriched);

    try {
      await map.style.addSource(
        GeoJsonSource(id: 'pireps', data: geojsonStr),
      );

      // Base circles — default gray, override with data-driven color
      await map.style.addLayer(CircleLayer(
        id: 'pirep-circles',
        sourceId: 'pireps',
        circleRadius: 6.0,
        circleColor: const Color(0xFFB0B4BC).toARGB32(),
        circleStrokeWidth: 1.5,
        circleStrokeColor: Colors.white.withValues(alpha: 0.6).toARGB32(),
        circleOpacity: 0.85,
      ));

      // Override circle-color with data-driven expression
      await map.style.setStyleLayerProperty(
        'pirep-circles',
        'circle-color',
        ['get', 'color'],
      );

      // Urgent PIREPs get a larger outer ring
      await map.style.addLayer(CircleLayer(
        id: 'pirep-urgent-ring',
        sourceId: 'pireps',
        circleRadius: 10.0,
        circleColor: const Color(0x00000000).toARGB32(),
        circleStrokeWidth: 2.0,
        circleStrokeColor: AppColors.error.toARGB32(),
        circleOpacity: 0.7,
        filter: ['==', ['get', 'isUrgent'], true],
      ));
    } catch (e) {
      debugPrint('Failed to add PIREP layers: $e');
    }
  }

  Map<String, dynamic> _enrichGeoJson(Map<String, dynamic> original) {
    final features = (original['features'] as List<dynamic>?) ?? [];
    final enrichedFeatures = features.map((f) {
      final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
      final props =
          Map<String, dynamic>.from(feature['properties'] as Map? ?? {});

      final tbInt = (props['tbInt1'] as String? ?? '').toUpperCase();
      final airepType = props['airepType'] as String? ?? '';
      props['color'] = _turbulenceColorHex(tbInt);
      props['isUrgent'] = airepType == 'URGENT PIREP';

      feature['properties'] = props;
      return feature;
    }).toList();

    return {
      'type': 'FeatureCollection',
      'features': enrichedFeatures,
    };
  }

  String _turbulenceColorHex(String intensity) {
    switch (intensity) {
      case 'NEG':
      case 'SMTH':
      case 'SMOOTH':
        return '#4CAF50';
      case 'LGT':
      case 'LIGHT':
      case 'LGT-MOD':
        return '#29B6F6';
      case 'MOD':
      case 'MODERATE':
      case 'MOD-SEV':
        return '#FFC107';
      case 'SEV':
      case 'SEVERE':
      case 'SEV-EXTM':
      case 'EXTM':
      case 'EXTREME':
        return '#FF5252';
      default:
        return '#B0B4BC';
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
            layerIds: ['pirep-circles', 'pirep-urgent-ring']),
      );

      if (results.isNotEmpty && results.first != null) {
        final props = results.first!.queriedFeature.feature['properties'];
        if (props is Map) {
          widget.onFeatureTapped
              ?.call(Map<String, dynamic>.from(props));
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to query PIREP feature: $e');
    }

    // Tapped empty area
    widget.onFeatureTapped?.call({});
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('pirep-map'),
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

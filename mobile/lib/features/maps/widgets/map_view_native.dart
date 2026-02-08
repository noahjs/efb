import 'dart:convert';

import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'map_view.dart' show EfbMapController, MapBounds, mapboxAccessToken;

/// Native (iOS/Android) implementation using mapbox_maps_flutter SDK.
class PlatformMapView extends StatefulWidget {
  final String baseLayer;
  final bool showFlightCategory;
  final bool interactive;
  final ValueChanged<String>? onAirportTapped;
  final ValueChanged<MapBounds>? onBoundsChanged;
  final List<Map<String, dynamic>> airports;
  final List<List<double>> routeCoordinates;
  final EfbMapController? controller;
  final Map<String, dynamic>? airspaceGeoJson;
  final Map<String, dynamic>? airwayGeoJson;
  final Map<String, dynamic>? artccGeoJson;

  const PlatformMapView({
    super.key,
    required this.baseLayer,
    this.showFlightCategory = false,
    this.interactive = true,
    this.onAirportTapped,
    this.onBoundsChanged,
    this.airports = const [],
    this.routeCoordinates = const [],
    this.controller,
    this.airspaceGeoJson,
    this.airwayGeoJson,
    this.artccGeoJson,
  });

  @override
  State<PlatformMapView> createState() => _PlatformMapViewState();
}

class _PlatformMapViewState extends State<PlatformMapView> {
  MapboxMap? _mapboxMap;
  bool _airportSourceReady = false;
  bool _routeSourceReady = false;
  bool _aeroSourceReady = false;

  static const _vfrCharts = ['Denver', 'Cheyenne', 'Albuquerque', 'Salt_Lake_City'];

  static String _styleForLayer(String layer) {
    switch (layer) {
      case 'street':
        return MapboxStyles.MAPBOX_STREETS;
      case 'vfr':
      case 'satellite':
      default:
        return MapboxStyles.SATELLITE_STREETS;
    }
  }

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void didUpdateWidget(covariant PlatformMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapboxMap == null) return;
    if (oldWidget.baseLayer != widget.baseLayer) {
      _switchLayer(oldWidget.baseLayer, widget.baseLayer);
    }
    if (oldWidget.showFlightCategory != widget.showFlightCategory) {
      _applyFlightCategoryMode(widget.showFlightCategory);
    }
    if (oldWidget.interactive != widget.interactive) {
      _setInteractive(widget.interactive);
    }
    if (oldWidget.airports != widget.airports) {
      _updateAirportsSource();
    }
    if (oldWidget.routeCoordinates != widget.routeCoordinates) {
      _updateRouteSource();
    }
    if (oldWidget.airspaceGeoJson != widget.airspaceGeoJson ||
        oldWidget.airwayGeoJson != widget.airwayGeoJson ||
        oldWidget.artccGeoJson != widget.artccGeoJson) {
      _updateAeronauticalSources();
    }
  }

  void _setInteractive(bool enabled) {
    final map = _mapboxMap;
    if (map == null) return;
    final gestures = map.gestures;
    gestures.updateSettings(GesturesSettings(
      scrollEnabled: enabled,
      pinchToZoomEnabled: enabled,
      doubleTapToZoomInEnabled: enabled,
      doubleTouchToZoomOutEnabled: enabled,
      rotateEnabled: enabled,
    ));
  }

  Future<void> _switchLayer(String oldLayer, String newLayer) async {
    final map = _mapboxMap!;
    final oldStyle = _styleForLayer(oldLayer);
    final newStyle = _styleForLayer(newLayer);

    if (oldStyle != newStyle) {
      // Different Mapbox style — full swap; _onStyleLoaded will re-add layers
      await map.loadStyleURI(newStyle);
    } else {
      // Same Mapbox style — just toggle VFR layer visibility
      await _setVfrVisibility(map, newLayer == 'vfr');
    }
  }

  Future<void> _setVfrVisibility(MapboxMap map, bool visible) async {
    final value = visible ? Visibility.VISIBLE : Visibility.NONE;
    try {
      for (final chart in _vfrCharts) {
        await map.style.setStyleLayerProperty(
          'vfr-layer-$chart',
          'visibility',
          value.name.toLowerCase(),
        );
      }
    } catch (e) {
      debugPrint('Failed to toggle VFR visibility: $e');
    }
  }

  Future<void> _applyFlightCategoryMode(bool enabled) async {
    final map = _mapboxMap;
    if (map == null || !_airportSourceReady) return;

    try {
      if (enabled) {
        // Colored dots by flight category, with labels
        await map.style.setStyleLayerProperty('airport-dots', 'circle-radius', 7.0);
        await map.style.setStyleLayerProperty(
          'airport-dots',
          'circle-color',
          ['match', ['get', 'category'],
            'VFR', '#00C853',
            'MVFR', '#2196F3',
            'IFR', '#FF1744',
            'LIFR', '#E040FB',
            '#888888'],
        );
        await map.style.setStyleLayerProperty('airport-dots', 'circle-stroke-width', 1.5);
        await map.style.setStyleLayerProperty(
          'airport-labels', 'visibility', 'visible',
        );
      } else {
        // Small gray dots, no labels
        await map.style.setStyleLayerProperty('airport-dots', 'circle-radius', 5.0);
        await map.style.setStyleLayerProperty('airport-dots', 'circle-color', '#888888');
        await map.style.setStyleLayerProperty('airport-dots', 'circle-stroke-width', 0.5);
        await map.style.setStyleLayerProperty(
          'airport-labels', 'visibility', 'none',
        );
      }
    } catch (e) {
      debugPrint('Failed to apply flight category mode: $e');
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    // Register tap listener for airport markers
    mapboxMap.setOnMapTapListener(_onMapTap);

    // Bind zoom controller
    widget.controller?.onZoomIn = () async {
      final cam = await mapboxMap.getCameraState();
      mapboxMap.flyTo(
        CameraOptions(zoom: cam.zoom + 1),
        MapAnimationOptions(duration: 300),
      );
    };
    widget.controller?.onZoomOut = () async {
      final cam = await mapboxMap.getCameraState();
      mapboxMap.flyTo(
        CameraOptions(zoom: cam.zoom - 1),
        MapAnimationOptions(duration: 300),
      );
    };
  }

  void _onMapIdle(MapIdleEventData data) {
    _fireBounds();
  }

  Future<void> _fireBounds() async {
    final map = _mapboxMap;
    if (map == null || widget.onBoundsChanged == null) return;

    try {
      final cam = await map.getCameraState();
      final bounds = await map.coordinateBoundsForCamera(CameraOptions(
        center: cam.center,
        zoom: cam.zoom,
        bearing: cam.bearing,
        pitch: cam.pitch,
      ));
      widget.onBoundsChanged?.call((
        minLat: bounds.southwest.coordinates.lat.toDouble(),
        maxLat: bounds.northeast.coordinates.lat.toDouble(),
        minLng: bounds.southwest.coordinates.lng.toDouble(),
        maxLng: bounds.northeast.coordinates.lng.toDouble(),
      ));
    } catch (e) {
      debugPrint('Failed to get map bounds: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _mapboxMap;
    if (map == null || widget.onAirportTapped == null) return;

    final point = context.touchPosition;
    final screenCoord = ScreenCoordinate(x: point.x, y: point.y);

    try {
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
        RenderedQueryOptions(layerIds: ['airport-dots']),
      );

      if (features.isNotEmpty) {
        final feature = features.first;
        final props = feature?.queriedFeature.feature['properties'];
        if (props is Map && props.containsKey('id')) {
          final id = props['id'] as String;
          widget.onAirportTapped?.call(id);
        }
      }
    } catch (e) {
      debugPrint('Failed to query airport features: $e');
    }
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    if (_mapboxMap == null) return;
    await _addVfrTiles(_mapboxMap!);
    await _addAeronauticalLayers(_mapboxMap!);
    await _addAirportLayers(_mapboxMap!);
    await _addRouteLayer(_mapboxMap!);
    await _applyFlightCategoryMode(widget.showFlightCategory);
    // Push current data into the fresh sources
    _updateAirportsSource();
    _updateRouteSource();
    _updateAeronauticalSources();
    // Fire initial bounds
    _fireBounds();
  }

  String _buildAirportsGeoJson() {
    final features = widget.airports.where((a) {
      return a['latitude'] != null && a['longitude'] != null;
    }).map((a) {
      final id = a['identifier'] ?? a['icao_identifier'] ?? '';
      final lng = a['longitude'];
      final lat = a['latitude'];
      final category = a['category'] ?? 'unknown';
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
        'properties': {
          'id': id,
          'category': category,
        },
      };
    }).toList();

    return jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  Future<void> _updateAirportsSource() async {
    if (!_airportSourceReady || _mapboxMap == null) return;
    try {
      final geojson = _buildAirportsGeoJson();
      await _mapboxMap!.style.setStyleSourceProperty(
        'airports',
        'data',
        geojson,
      );
    } catch (e) {
      debugPrint('Failed to update airports source: $e');
    }
  }

  Future<void> _addVfrTiles(MapboxMap map) async {
    final visibility = widget.baseLayer == 'vfr'
        ? Visibility.VISIBLE
        : Visibility.NONE;
    try {
      for (final chart in _vfrCharts) {
        await map.style.addSource(RasterSource(
          id: 'vfr-$chart',
          tiles: [
            'http://localhost:3001/api/tiles/vfr-sectional/$chart/{z}/{x}/{y}.png'
          ],
          tileSize: 256,
          minzoom: 5,
          maxzoom: 11,
          attribution: 'FAA VFR Sectional: $chart',
        ));

        await map.style.addLayer(RasterLayer(
          id: 'vfr-layer-$chart',
          sourceId: 'vfr-$chart',
          rasterOpacity: 0.85,
          visibility: visibility,
        ));
      }
    } catch (e) {
      debugPrint('Failed to add VFR tiles: $e');
    }
  }

  /// Creates the airports GeoJSON source (empty initially) and the dot/label layers.
  /// Flight category mode is applied separately via [_applyFlightCategoryMode].
  Future<void> _addAirportLayers(MapboxMap map) async {
    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

    try {
      await map.style
          .addSource(GeoJsonSource(id: 'airports', data: emptyGeoJson));

      await map.style.addLayer(CircleLayer(
        id: 'airport-dots',
        sourceId: 'airports',
        circleRadius: 5.0,
        circleColor: const Color(0xFF888888).toARGB32(),
        circleStrokeWidth: 0.5,
        circleStrokeColor: Colors.white.withValues(alpha: 0.3).toARGB32(),
      ));

      await map.style.addLayer(SymbolLayer(
        id: 'airport-labels',
        sourceId: 'airports',
        textField: '{id}',
        textSize: 11.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, -1.5],
        textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
        visibility: Visibility.NONE,
      ));

      _airportSourceReady = true;
    } catch (e) {
      debugPrint('Failed to add airport layers: $e');
    }
  }

  /// Creates the route GeoJSON source and a cyan LineLayer.
  Future<void> _addRouteLayer(MapboxMap map) async {
    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';
    try {
      await map.style
          .addSource(GeoJsonSource(id: 'route', data: emptyGeoJson));

      await map.style.addLayer(LineLayer(
        id: 'route-line',
        sourceId: 'route',
        lineColor: const Color(0xFF00FFFF).toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.9,
      ));

      _routeSourceReady = true;
    } catch (e) {
      debugPrint('Failed to add route layer: $e');
    }
  }

  String _buildRouteGeoJson() {
    if (widget.routeCoordinates.length < 2) {
      return '{"type":"FeatureCollection","features":[]}';
    }
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': widget.routeCoordinates,
          },
          'properties': {},
        }
      ],
    });
  }

  Future<void> _updateRouteSource() async {
    if (!_routeSourceReady || _mapboxMap == null) return;
    try {
      final geojson = _buildRouteGeoJson();
      await _mapboxMap!.style.setStyleSourceProperty('route', 'data', geojson);
    } catch (e) {
      debugPrint('Failed to update route source: $e');
    }
  }

  /// Creates aeronautical GeoJSON sources and layers (airspaces, airways, ARTCC).
  /// Added below VFR tiles but above airport dots so airspace fills don't cover airports.
  Future<void> _addAeronauticalLayers(MapboxMap map) async {
    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

    try {
      // ARTCC boundaries (bottom layer — gray dashed)
      await map.style
          .addSource(GeoJsonSource(id: 'artcc', data: emptyGeoJson));
      await map.style.addLayer(LineLayer(
        id: 'artcc-lines',
        sourceId: 'artcc',
        lineColor: const Color(0xFF999999).toARGB32(),
        lineWidth: 1.0,
        lineOpacity: 0.6,
        lineDasharray: [4.0, 4.0],
      ));

      // Airways (thin light-blue lines)
      await map.style
          .addSource(GeoJsonSource(id: 'airways', data: emptyGeoJson));
      await map.style.addLayer(LineLayer(
        id: 'airway-lines',
        sourceId: 'airways',
        lineColor: const Color(0xFF64B5F6).toARGB32(),
        lineWidth: 1.0,
        lineOpacity: 0.7,
      ));

      // Airspaces (fill + border)
      await map.style
          .addSource(GeoJsonSource(id: 'airspaces', data: emptyGeoJson));
      await map.style.addLayer(FillLayer(
        id: 'airspace-fill',
        sourceId: 'airspaces',
        fillOpacity: 0.1,
        fillColor: const Color(0xFF2196F3).toARGB32(),
      ));
      await map.style.addLayer(LineLayer(
        id: 'airspace-border',
        sourceId: 'airspaces',
        lineWidth: 2.0,
        lineColor: const Color(0xFF2196F3).toARGB32(),
        lineOpacity: 0.8,
      ));

      _aeroSourceReady = true;
    } catch (e) {
      debugPrint('Failed to add aeronautical layers: $e');
    }
  }

  Future<void> _updateAeronauticalSources() async {
    if (!_aeroSourceReady || _mapboxMap == null) return;

    try {
      // Update airspaces
      final airspaceData = widget.airspaceGeoJson != null
          ? jsonEncode(widget.airspaceGeoJson)
          : '{"type":"FeatureCollection","features":[]}';
      await _mapboxMap!.style
          .setStyleSourceProperty('airspaces', 'data', airspaceData);

      // Update airways
      final airwayData = widget.airwayGeoJson != null
          ? jsonEncode(widget.airwayGeoJson)
          : '{"type":"FeatureCollection","features":[]}';
      await _mapboxMap!.style
          .setStyleSourceProperty('airways', 'data', airwayData);

      // Update ARTCC
      final artccData = widget.artccGeoJson != null
          ? jsonEncode(widget.artccGeoJson)
          : '{"type":"FeatureCollection","features":[]}';
      await _mapboxMap!.style
          .setStyleSourceProperty('artcc', 'data', artccData);
    } catch (e) {
      debugPrint('Failed to update aeronautical sources: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('efb-mapbox'),
      styleUri: _styleForLayer(widget.baseLayer),
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(-104.8493, 39.5701)),
        zoom: 8.5,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onMapIdleListener: _onMapIdle,
    );
  }
}

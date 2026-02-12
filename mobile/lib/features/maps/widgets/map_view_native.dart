import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/config/app_config.dart';
import 'map_view.dart' show EfbMapController, MapBounds;
import 'airport_symbol_renderer.dart';
import 'wind_barb_renderer.dart';
import 'wind_arrow_renderer.dart';
import 'wind_heatmap_controller.dart';
import 'wind_particle_animator.dart';

/// Native (iOS/Android) implementation using mapbox_maps_flutter SDK.
class PlatformMapView extends StatefulWidget {
  final String baseLayer;
  final bool showFlightCategory;
  final bool interactive;
  final ValueChanged<String>? onAirportTapped;
  final ValueChanged<String>? onNavaidTapped;
  final ValueChanged<String>? onFixTapped;
  final ValueChanged<Map<String, dynamic>>? onPirepTapped;
  final ValueChanged<MapBounds>? onBoundsChanged;
  final void Function(double lat, double lng, List<Map<String, dynamic>> aeroFeatures)? onMapLongPressed;
  final VoidCallback? onMapTapped;
  final List<Map<String, dynamic>> airports;
  final List<List<double>> routeCoordinates;
  final EfbMapController? controller;
  final Map<String, Map<String, dynamic>?> overlays;

  const PlatformMapView({
    super.key,
    required this.baseLayer,
    this.showFlightCategory = false,
    this.interactive = true,
    this.onAirportTapped,
    this.onNavaidTapped,
    this.onFixTapped,
    this.onPirepTapped,
    this.onBoundsChanged,
    this.onMapLongPressed,
    this.onMapTapped,
    this.airports = const [],
    this.routeCoordinates = const [],
    this.controller,
    this.overlays = const {},
  });

  @override
  State<PlatformMapView> createState() => _PlatformMapViewState();
}

class _PlatformMapViewState extends State<PlatformMapView> {
  MapboxMap? _mapboxMap;
  bool _airportSourceReady = false;
  bool _routeSourceReady = false;
  final Set<String> _overlaySourcesReady = {};
  final _particleAnimator = WindParticleAnimator();

  static const _vfrCharts = ['Denver', 'Cheyenne', 'Albuquerque', 'Salt_Lake_City'];

  static String _styleForLayer(String layer) {
    switch (layer) {
      case 'street':
        return MapboxStyles.MAPBOX_STREETS;
      case 'dark':
        return MapboxStyles.DARK;
      case 'vfr':
      case 'satellite':
      default:
        return MapboxStyles.SATELLITE_STREETS;
    }
  }

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppConfig.mapboxToken);
  }

  @override
  void dispose() {
    _particleAnimator.stop();
    super.dispose();
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
    // Update any overlay sources that changed
    final allKeys = {...oldWidget.overlays.keys, ...widget.overlays.keys};
    for (final key in allKeys) {
      if (oldWidget.overlays[key] != widget.overlays[key]) {
        _updateOverlaySource(key);
      }
    }
    // Toggle hillshade visibility with winds aloft overlay
    final hadWinds = oldWidget.overlays.containsKey('winds-aloft');
    final hasWinds = widget.overlays.containsKey('winds-aloft');
    if (hadWinds != hasWinds) {
      _setHillshadeVisibility(hasWinds);
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

  Future<void> _setHillshadeVisibility(bool visible) async {
    final map = _mapboxMap;
    if (map == null) return;
    try {
      await map.style.setStyleLayerProperty(
        'hillshade-terrain',
        'visibility',
        visible ? 'visible' : 'none',
      );
    } catch (e) {
      debugPrint('Failed to toggle hillshade: $e');
    }
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

    final catVis = enabled ? 'visible' : 'none';

    try {
      // Toggle colored category halo circles behind symbols
      for (final cat in _flightCategoryColors.keys) {
        await map.style.setStyleLayerProperty(
          'airport-dots-${cat.toLowerCase()}', 'visibility', catVis,
        );
      }

      // Toggle labels
      await map.style.setStyleLayerProperty(
        'airport-labels', 'visibility', catVis,
      );
    } catch (e) {
      debugPrint('Failed to apply flight category mode: $e');
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    // Register tap listener for airport markers
    mapboxMap.setOnMapTapListener(_onMapTap);

    // Register long-press listener for aeronautical feature inspection
    mapboxMap.setOnMapLongTapListener(_onMapLongTap);

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

    // Bind flyTo controller
    widget.controller?.onFlyTo = (double lat, double lng, {double? zoom}) {
      mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: zoom ?? 11,
        ),
        MapAnimationOptions(duration: 1000),
      );
    };

    // Bind follow-mode camera (shorter animation, preserves zoom)
    widget.controller?.onFollowTo =
        (double lat, double lng, {double bearing = 0}) async {
      final cam = await mapboxMap.getCameraState();
      mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          bearing: bearing,
          zoom: cam.zoom,
        ),
        MapAnimationOptions(duration: 400),
      );
    };

    // Bind particle animation to controller
    _particleAnimator.attach(mapboxMap);
    widget.controller?.onUpdateParticleField = (windField,
        {required minLat, required maxLat, required minLng, required maxLng}) {
      final points = windField
          .map((wf) => WindFieldPoint(
                lat: (wf['lat'] as num).toDouble(),
                lng: (wf['lng'] as num).toDouble(),
                direction: (wf['direction'] as num).toDouble(),
                speed: (wf['speed'] as num).toDouble(),
              ))
          .toList();
      _particleAnimator.updateWindField(points,
          minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
    };
    widget.controller?.onUpdateParticleViewport =
        ({required minLat, required maxLat, required minLng, required maxLng}) {
      _particleAnimator.updateViewport(
          minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
    };
    widget.controller?.onStartParticles = () {
      if (!_particleAnimator.isRunning) _particleAnimator.start();
    };
    widget.controller?.onStopParticles = () => _particleAnimator.stop();
    widget.controller?.getParticlesRunning = () => _particleAnimator.isRunning;

    // Notify controller that map is ready
    widget.controller?.onMapReady?.call(mapboxMap);
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
    if (map == null) return;

    // Dismiss any open feature sheet before checking for new features
    widget.onMapTapped?.call();

    final point = context.touchPosition;
    final screenCoord = ScreenCoordinate(x: point.x, y: point.y);

    // Check PIREPs first (smaller targets, higher priority)
    if (widget.onPirepTapped != null) {
      try {
        final pirepFeatures = await map.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
          RenderedQueryOptions(layerIds: ['pirep-symbols', 'pirep-urgent-ring']),
        );
        if (pirepFeatures.isNotEmpty) {
          final feature = pirepFeatures.first;
          final props = feature?.queriedFeature.feature['properties'];
          if (props is Map) {
            widget.onPirepTapped?.call(Map<String, dynamic>.from(props));
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to query PIREP features: $e');
      }
    }

    // Then check airports
    if (widget.onAirportTapped != null) {
      try {
        final airportLayerIds = [
          // VFR symbol layers (one per airport type)
          for (final st in AirportSymbolRenderer.symbolTypes) 'airport-sym-$st',
          // Flight category halo circles
          'airport-dots-vfr',
          'airport-dots-mvfr',
          'airport-dots-ifr',
          'airport-dots-lifr',
        ];
        final features = await map.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
          RenderedQueryOptions(layerIds: airportLayerIds),
        );

        if (features.isNotEmpty) {
          final feature = features.first;
          final props = feature?.queriedFeature.feature['properties'];
          if (props is Map && props.containsKey('id')) {
            final id = props['id'] as String;
            widget.onAirportTapped?.call(id);
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to query airport features: $e');
      }
    }

    // Then check navaids
    if (widget.onNavaidTapped != null) {
      try {
        final features = await map.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
          RenderedQueryOptions(layerIds: ['navaid-symbols']),
        );
        if (features.isNotEmpty) {
          final props = features.first?.queriedFeature.feature['properties'];
          if (props is Map && props.containsKey('identifier')) {
            widget.onNavaidTapped?.call(props['identifier'] as String);
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to query navaid features: $e');
      }
    }

    // Then check fixes
    if (widget.onFixTapped != null) {
      try {
        final features = await map.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
          RenderedQueryOptions(layerIds: ['fix-symbols']),
        );
        if (features.isNotEmpty) {
          final props = features.first?.queriedFeature.feature['properties'];
          if (props is Map && props.containsKey('identifier')) {
            widget.onFixTapped?.call(props['identifier'] as String);
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to query fix features: $e');
      }
    }
  }

  Future<void> _onMapLongTap(MapContentGestureContext context) async {
    final map = _mapboxMap;
    if (map == null || widget.onMapLongPressed == null) return;

    final coords = context.point.coordinates;
    final lat = coords.lat.toDouble();
    final lng = coords.lng.toDouble();
    final point = context.touchPosition;
    // Use a 20px box around the tap point to catch nearby airspace edges
    const pad = 20.0;
    final queryBox = RenderedQueryGeometry.fromScreenBox(ScreenBox(
      min: ScreenCoordinate(x: point.x - pad, y: point.y - pad),
      max: ScreenCoordinate(x: point.x + pad, y: point.y + pad),
    ));

    final layerMap = {
      'airspace-fill': 'airspace',
      'artcc-lines': 'artcc',
      'airway-lines': 'airway',
      'tfr-fill': 'tfr',
      'advisory-fill': 'advisory',
    };

    final allFeatures = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    try {
      for (final entry in layerMap.entries) {
        final results = await map.queryRenderedFeatures(
          queryBox,
          RenderedQueryOptions(layerIds: [entry.key]),
        );
        for (final result in results) {
          if (result == null) continue;
          final props = result.queriedFeature.feature['properties'];
          if (props is Map) {
            // Build dedup key based on layer type
            String dedupKey;
            if (entry.value == 'advisory') {
              // Advisories lack id/name — use hazard + tag/seriesId + validTime
              final hazard = (props['hazard'] ?? '').toString();
              final tag = (props['tag'] ?? props['seriesId'] ?? props['cwsu'] ?? '').toString();
              final time = (props['validTime'] ?? props['validTimeFrom'] ?? '').toString();
              dedupKey = 'advisory:$hazard|$tag|$time';
            } else {
              final id = (props['id'] ?? props['name'] ?? '').toString();
              dedupKey = '${entry.value}:$id';
            }
            if (seenIds.contains(dedupKey)) continue;
            seenIds.add(dedupKey);
            final featureMap = Map<String, dynamic>.from(props);
            featureMap['_layerType'] = entry.value;
            allFeatures.add(featureMap);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to query aero features on long-press: $e');
    }

    widget.onMapLongPressed?.call(lat, lng, allFeatures);
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    if (_mapboxMap == null) return;
    await _addVfrTiles(_mapboxMap!);
    await _addHillshadeLayer(_mapboxMap!);
    // Register airport symbol images for VFR chart-style markers
    await _registerAirportSymbolImages(_mapboxMap!);
    // Register wind barb images and arrow for the symbol layer
    await _registerWindBarbImages(_mapboxMap!);
    await _registerWindArrowImage(_mapboxMap!);
    // Register own-position cone image and traffic chevron
    await _registerConeImage(_mapboxMap!);
    await _registerTrafficChevron(_mapboxMap!);
    // Wind heatmap raster layer — positioned above aero/hillshade,
    // below wind arrow overlays (which are added in the loop below).
    await WindHeatmapController.createHeatmapLayer(_mapboxMap!);
    // Register all overlay sources and layers
    for (final key in _overlayRegistry.keys) {
      await _addOverlaySource(_mapboxMap!, key);
    }
    await _addRouteLayer(_mapboxMap!);
    await _addAirportLayers(_mapboxMap!);
    await _applyFlightCategoryMode(widget.showFlightCategory);
    // Push current data into the fresh sources
    _updateAirportsSource();
    _updateRouteSource();
    for (final key in _overlayRegistry.keys) {
      _updateOverlaySource(key);
    }
    // Re-apply any custom overlays (e.g. approach plates)
    widget.controller?.onStyleReloaded?.call();
    // Fire initial bounds
    _fireBounds();
  }

  static const _flightCategoryColors = {
    'VFR': Color(0xFF00C853),
    'MVFR': Color(0xFF2196F3),
    'IFR': Color(0xFFFF1744),
    'LIFR': Color(0xFFE040FB),
  };

  String _buildAirportsGeoJson() {
    final features = widget.airports.where((a) {
      return a['latitude'] != null && a['longitude'] != null;
    }).map((a) {
      final id = a['icao_identifier'] ?? a['identifier'] ?? '';
      final lng = a['longitude'];
      final lat = a['latitude'];
      final category = a['category'] ?? 'unknown';
      final isWxStation = a['isWeatherStation'] == true;
      final symbolType = isWxStation
          ? 'apt-unknown'
          : AirportSymbolRenderer.classifyAirport(a);
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
        'properties': {
          'id': id,
          'category': category,
          'symbolType': symbolType,
        },
      };
    }).toList();

    // Debug: log symbol type distribution
    if (features.isNotEmpty) {
      final typeCounts = <String, int>{};
      for (final f in features) {
        final st = (f['properties'] as Map)['symbolType'] as String;
        typeCounts[st] = (typeCounts[st] ?? 0) + 1;
      }
      debugPrint('[EFB] Airport symbols: ${features.length} total, types: $typeCounts');
    }

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
            '${AppConfig.apiBaseUrl}/api/tiles/vfr-sectional/$chart/{z}/{x}/{y}.png'
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

  /// Creates the airports GeoJSON source and VFR chart-style symbol layers.
  /// One symbol layer per airport type (filtered by symbolType property).
  /// Flight category colored circles sit behind the symbols when that mode
  /// is active.
  Future<void> _addAirportLayers(MapboxMap map) async {
    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

    try {
      await map.style
          .addSource(GeoJsonSource(id: 'airports', data: emptyGeoJson));

      // Flight category halo circles — behind symbols, hidden by default
      for (final entry in _flightCategoryColors.entries) {
        await map.style.addLayer(CircleLayer(
          id: 'airport-dots-${entry.key.toLowerCase()}',
          sourceId: 'airports',
          circleRadius: 12.0,
          circleColor: entry.value.toARGB32(),
          circleOpacity: 0.35,
          circleStrokeWidth: 2.0,
          circleStrokeColor: entry.value.toARGB32(),
          filter: ['==', ['get', 'category'], entry.key],
          visibility: Visibility.NONE,
        ));
      }

      // One symbol layer per airport type, filtered by symbolType property
      debugPrint('[EFB] Adding ${AirportSymbolRenderer.symbolTypes.length} airport symbol layers');
      for (final symbolType in AirportSymbolRenderer.symbolTypes) {
        await map.style.addLayer(SymbolLayer(
          id: 'airport-sym-$symbolType',
          sourceId: 'airports',
          iconImage: symbolType,
          iconSize: 0.55,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          filter: ['==', ['get', 'symbolType'], symbolType],
        ));
      }

      // Airport labels (hidden by default, shown in flight category mode)
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

  /// Creates the route GeoJSON source and line layers.
  /// Border (faint black), first leg (magenta), remaining legs (lighter cyan).
  Future<void> _addRouteLayer(MapboxMap map) async {
    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';
    try {
      await map.style
          .addSource(GeoJsonSource(id: 'route', data: emptyGeoJson));

      // Black border behind all route lines
      await map.style.addLayer(LineLayer(
        id: 'route-line-border',
        sourceId: 'route',
        lineColor: const Color(0xFF000000).toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.4,
      ));

      // Remaining legs — lighter cyan
      await map.style.addLayer(LineLayer(
        id: 'route-line',
        sourceId: 'route',
        lineColor: const Color(0xFFFFFFFF).toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.85,
        filter: ['!=', ['get', 'leg'], 'first'],
      ));

      // First leg — magenta
      await map.style.addLayer(LineLayer(
        id: 'route-line-first',
        sourceId: 'route',
        lineColor: const Color(0xFFFF00FF).toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.85,
        filter: ['==', ['get', 'leg'], 'first'],
      ));

      // Waypoint dots at each route coordinate — explicitly above route lines
      await map.style.addLayerAt(
        CircleLayer(
          id: 'route-waypoint-dots',
          sourceId: 'route',
          circleRadius: 6.0,
          circleColor: const Color(0xFF888888).toARGB32(),
          circleStrokeWidth: 1.5,
          circleStrokeColor: const Color(0x99FFFFFF).toARGB32(),
          filter: ['==', ['geometry-type'], 'Point'],
        ),
        LayerPosition(above: 'route-line-first'),
      );

      _routeSourceReady = true;
    } catch (e) {
      debugPrint('Failed to add route layer: $e');
    }
  }

  String _buildRouteGeoJson() {
    if (widget.routeCoordinates.length < 2) {
      return '{"type":"FeatureCollection","features":[]}';
    }
    final coords = widget.routeCoordinates;
    final features = <Map<String, dynamic>>[];
    // First leg (magenta)
    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [coords[0], coords[1]],
      },
      'properties': {'leg': 'first'},
    });
    // Remaining legs (cyan)
    if (coords.length > 2) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': coords.sublist(1),
        },
        'properties': {'leg': 'rest'},
      });
    }
    // Waypoint dots at each coordinate
    for (final coord in coords) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': coord,
        },
        'properties': {'isWaypoint': true},
      });
    }
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
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
  // ── Generic GeoJSON Overlay System ──
  //
  // To add a new overlay, just add an entry to [_overlayRegistry] with a
  // callback that creates the Mapbox layers for that source.  Then pass data
  // under the same key in the `overlays` map from the parent widget.
  // Everything else (source creation, data updates, style reloads) is handled
  // automatically.

  /// Registry of overlay source IDs → layer-setup callbacks.
  /// The callback receives the MapboxMap and the source ID, and should call
  /// `map.style.addLayer(...)` for each layer it needs.
  static final Map<String, Future<void> Function(MapboxMap map, String srcId)>
      _overlayRegistry = {
    // Aeronautical sub-layers (bottom, so other overlays render on top)
    'artcc': _setupArtccLayers,
    'airways': _setupAirwayLayers,
    'airspaces': _setupAirspaceLayers,
    'navaids': _setupNavaidLayers,
    'fixes': _setupFixLayers,
    // Situational overlays
    'tfrs': _setupTfrLayers,
    'advisories': _setupAdvisoryLayers,
    'pireps': _setupPirepLayers,
    'metar-overlay': _setupMetarOverlayLayers,
    'traffic': _setupTrafficLayers,
    'winds-aloft': _setupWindsAloftLayers,
    'wind-streamlines': _setupStreamlineLayers,
    'breadcrumb': _setupBreadcrumbLayers,
    'own-position': _setupOwnPositionLayers,
  };

  /// Creates a GeoJSON source and its layers for the given overlay key.
  Future<void> _addOverlaySource(MapboxMap map, String key) async {
    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';
    try {
      await map.style
          .addSource(GeoJsonSource(id: key, data: emptyGeoJson));
      await _overlayRegistry[key]!(map, key);
      _overlaySourcesReady.add(key);
    } catch (e) {
      debugPrint('Failed to add overlay layers for $key: $e');
    }
  }

  /// Pushes the current GeoJSON data into an overlay source.
  Future<void> _updateOverlaySource(String key) async {
    if (!_overlaySourcesReady.contains(key) || _mapboxMap == null) return;
    try {
      final geojson = widget.overlays[key];
      final data = geojson != null
          ? jsonEncode(geojson)
          : '{"type":"FeatureCollection","features":[]}';
      await _mapboxMap!.style.setStyleSourceProperty(key, 'data', data);
    } catch (e) {
      debugPrint('Failed to update overlay source $key: $e');
    }
  }

  // ── Layer setup callbacks (one per overlay type) ──

  // ── Aeronautical layer setup callbacks ──

  static Future<void> _setupArtccLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(LineLayer(
      id: 'artcc-lines',
      sourceId: srcId,
      lineColor: const Color(0xFF999999).toARGB32(),
      lineWidth: 1.0,
      lineOpacity: 0.6,
      lineDasharray: [4.0, 4.0],
    ));
  }

  static Future<void> _setupAirwayLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(LineLayer(
      id: 'airway-lines',
      sourceId: srcId,
      lineColor: const Color(0xFF64B5F6).toARGB32(),
      lineWidth: 1.0,
      lineOpacity: 0.7,
    ));
  }

  static Future<void> _setupAirspaceLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(FillLayer(
      id: 'airspace-fill',
      sourceId: srcId,
      fillOpacity: 0.1,
      fillColor: const Color(0xFF2196F3).toARGB32(),
    ));
    await map.style.addLayer(LineLayer(
      id: 'airspace-border',
      sourceId: srcId,
      lineWidth: 2.0,
      lineColor: const Color(0xFF2196F3).toARGB32(),
      lineOpacity: 0.8,
    ));
  }

  static Future<void> _setupNavaidLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(SymbolLayer(
      id: 'navaid-symbols',
      sourceId: srcId,
      textField: '{identifier}',
      textSize: 10.0,
      textColor: const Color(0xFF90CAF9).toARGB32(),
      textHaloColor: const Color(0xFF000000).toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, 1.2],
      textOptional: true,
      iconImage: 'airport-dot', // reuse existing small dot
      iconSize: 0.5,
      iconColor: const Color(0xFF90CAF9).toARGB32(),
    ));
  }

  static Future<void> _setupFixLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(SymbolLayer(
      id: 'fix-symbols',
      sourceId: srcId,
      textField: '{identifier}',
      textSize: 9.0,
      textColor: const Color(0xFF80CBC4).toARGB32(),
      textHaloColor: const Color(0xFF000000).toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, 1.2],
      textOptional: true,
      iconImage: 'airport-dot', // reuse existing small dot
      iconSize: 0.4,
      iconColor: const Color(0xFF80CBC4).toARGB32(),
    ));
  }

  // ── Situational overlay layer setup callbacks ──

  static Future<void> _setupTfrLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(FillLayer(
      id: 'tfr-fill',
      sourceId: srcId,
      fillColor: const Color(0xFFFF5252).toARGB32(),
      fillOpacity: 0.15,
    ));
    await map.style.setStyleLayerProperty('tfr-fill', 'fill-color', ['get', 'color']);

    await map.style.addLayer(LineLayer(
      id: 'tfr-outline',
      sourceId: srcId,
      lineColor: const Color(0xFFFF5252).toARGB32(),
      lineWidth: 2.0,
      lineOpacity: 0.8,
    ));
    await map.style.setStyleLayerProperty('tfr-outline', 'line-color', ['get', 'color']);
  }

  static Future<void> _setupAdvisoryLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(FillLayer(
      id: 'advisory-fill',
      sourceId: srcId,
      fillColor: const Color(0xFFB0B4BC).toARGB32(),
      fillOpacity: 0.15,
      filter: ['==', ['geometry-type'], 'Polygon'],
    ));
    await map.style.setStyleLayerProperty('advisory-fill', 'fill-color', ['get', 'color']);

    await map.style.addLayer(LineLayer(
      id: 'advisory-outline',
      sourceId: srcId,
      lineColor: const Color(0xFFB0B4BC).toARGB32(),
      lineWidth: 2.0,
      filter: ['==', ['geometry-type'], 'Polygon'],
    ));
    await map.style.setStyleLayerProperty('advisory-outline', 'line-color', ['get', 'color']);

    await map.style.addLayer(LineLayer(
      id: 'advisory-line',
      sourceId: srcId,
      lineColor: const Color(0xFFB0B4BC).toARGB32(),
      lineWidth: 2.0,
      lineDasharray: [5.0, 3.0],
      filter: ['==', ['geometry-type'], 'LineString'],
    ));
    await map.style.setStyleLayerProperty('advisory-line', 'line-color', ['get', 'color']);
  }

  static Future<void> _setupPirepLayers(MapboxMap map, String srcId) async {
    // Symbol layer using Unicode characters (same as imagery PIREP viewer)
    await map.style.addLayer(SymbolLayer(
      id: 'pirep-symbols',
      sourceId: srcId,
      textField: '{symbol}',
      textSize: 16.0,
      textAllowOverlap: true,
      textIgnorePlacement: true,
      textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
    ));
    await map.style.setStyleLayerProperty(
      'pirep-symbols', 'text-color', ['get', 'color'],
    );

    // Urgent PIREPs get a red outer ring
    await map.style.addLayer(CircleLayer(
      id: 'pirep-urgent-ring',
      sourceId: srcId,
      circleRadius: 12.0,
      circleColor: const Color(0x00000000).toARGB32(),
      circleStrokeWidth: 2.0,
      circleStrokeColor: const Color(0xFFFF5252).toARGB32(),
      circleOpacity: 0.7,
      filter: ['==', ['get', 'isUrgent'], true],
    ));
  }

  static Future<void> _setupMetarOverlayLayers(MapboxMap map, String srcId) async {
    await map.style.addLayer(CircleLayer(
      id: 'metar-overlay-dots',
      sourceId: srcId,
      circleRadius: 7.0,
      circleColor: const Color(0xFF888888).toARGB32(),
      circleStrokeWidth: 1.5,
      circleStrokeColor: Colors.white.withValues(alpha: 0.3).toARGB32(),
    ));
    await map.style.setStyleLayerProperty('metar-overlay-dots', 'circle-color', ['get', 'color']);

    await map.style.addLayer(SymbolLayer(
      id: 'metar-overlay-labels',
      sourceId: srcId,
      textField: '{label}',
      textSize: 10.0,
      textColor: Colors.white.toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, -1.5],
      textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
    ));
  }

  static Future<void> _setupTrafficLayers(MapboxMap map, String srcId) async {
    // Leader lines (target → heads) — solid, drawn below dots
    await map.style.addLayer(LineLayer(
      id: 'traffic-leader-lines',
      sourceId: srcId,
      lineWidth: 2.5,
      lineOpacity: 0.9,
      lineColor: const Color(0xFFFFFFFF).toARGB32(),
      filter: ['==', ['get', 'featureType'], 'leader'],
    ));
    await map.style.setStyleLayerProperty('traffic-leader-lines', 'line-color', [
      'match',
      ['get', 'threat'],
      'resolution', '#FF5252',
      'alert', '#FF5252',
      'proximate', '#FFC107',
      '#AAAAAA',
    ]);

    // 5-min head markers (drawn first so 2-min is on top)
    await map.style.addLayer(CircleLayer(
      id: 'traffic-head-5min',
      sourceId: srcId,
      circleRadius: 2.5,
      circleColor: const Color(0xFFFFFFFF).toARGB32(),
      circleOpacity: 0.85,
      circleStrokeWidth: 0.5,
      circleStrokeColor: Colors.white.withValues(alpha: 0.9).toARGB32(),
      filter: ['all',
        ['==', ['get', 'featureType'], 'head'],
        ['==', ['get', 'head_interval'], 300],
      ],
    ));
    await map.style.setStyleLayerProperty('traffic-head-5min', 'circle-color', [
      'match',
      ['get', 'threat'],
      'resolution', '#FF5252',
      'alert', '#FF5252',
      'proximate', '#FFC107',
      '#FFFFFF',
    ]);

    // 2-min head markers
    await map.style.addLayer(CircleLayer(
      id: 'traffic-head-2min',
      sourceId: srcId,
      circleRadius: 3.0,
      circleColor: const Color(0xFFFFFFFF).toARGB32(),
      circleOpacity: 0.9,
      circleStrokeWidth: 0.5,
      circleStrokeColor: Colors.white.withValues(alpha: 0.9).toARGB32(),
      filter: ['all',
        ['==', ['get', 'featureType'], 'head'],
        ['==', ['get', 'head_interval'], 120],
      ],
    ));
    await map.style.setStyleLayerProperty('traffic-head-2min', 'circle-color', [
      'match',
      ['get', 'threat'],
      'resolution', '#FF5252',
      'alert', '#FF5252',
      'proximate', '#FFC107',
      '#FFFFFF',
    ]);

    // Head altitude labels
    await map.style.addLayer(SymbolLayer(
      id: 'traffic-head-alt-labels',
      sourceId: srcId,
      textField: '{alt_tag}',
      textSize: 8.0,
      textColor: Colors.white.withValues(alpha: 0.7).toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, 1.2],
      textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      filter: ['==', ['get', 'featureType'], 'head'],
    ));

    // Traffic target chevrons — directional markers colored by threat level
    await map.style.addLayer(SymbolLayer(
      id: 'traffic-dots',
      sourceId: srcId,
      iconImage: 'traffic-chevron',
      iconSize: 0.9,
      iconRotate: 0.0,
      iconRotationAlignment: IconRotationAlignment.MAP,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      filter: ['==', ['get', 'featureType'], 'target'],
    ));
    await map.style.setStyleLayerProperty(
        'traffic-dots', 'icon-rotate', ['get', 'track']);
    await map.style.setStyleLayerProperty('traffic-dots', 'icon-color', [
      'match',
      ['get', 'threat'],
      'resolution', '#FF5252',
      'alert', '#FF5252',
      'proximate', '#FFC107',
      '#FFFFFF',
    ]);

    // Callsign labels above the dot
    await map.style.addLayer(SymbolLayer(
      id: 'traffic-labels',
      sourceId: srcId,
      textField: '{callsign}',
      textSize: 10.0,
      textColor: Colors.white.toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, -1.8],
      textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      filter: ['==', ['get', 'featureType'], 'target'],
    ));

    // Relative altitude tag below the dot
    await map.style.addLayer(SymbolLayer(
      id: 'traffic-alt-labels',
      sourceId: srcId,
      textField: '{alt_tag}',
      textSize: 9.0,
      textColor: Colors.white.toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, 1.2],
      textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      filter: ['==', ['get', 'featureType'], 'target'],
    ));
  }

  static Future<void> _setupWindsAloftLayers(MapboxMap map, String srcId) async {
    debugPrint('[EFB] _setupWindsAloftLayers: using wind-arrow icons');
    // Directional arrow indicators — SDF image colored by wind speed
    await map.style.addLayer(SymbolLayer(
      id: 'winds-aloft-barbs',
      sourceId: srcId,
      iconImage: 'wind-arrow',
      iconSize: 0.45,
      iconRotate: 0.0,
      iconRotationAlignment: IconRotationAlignment.MAP,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
    ));
    // Data-driven rotation from feature properties
    await map.style.setStyleLayerProperty(
        'winds-aloft-barbs', 'icon-rotate', ['get', 'rotation']);
    // Data-driven color from feature properties
    await map.style.setStyleLayerProperty(
        'winds-aloft-barbs', 'icon-color', ['get', 'color']);

    // Speed labels below arrows (speed only, direction conveyed by arrow)
    await map.style.addLayer(SymbolLayer(
      id: 'winds-aloft-speed-labels',
      sourceId: srcId,
      textField: '{speedLabel}',
      textSize: 11.0,
      textColor: Colors.white.toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, 1.8],
      textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      textAllowOverlap: true,
      textIgnorePlacement: true,
    ));
    await map.style.setStyleLayerProperty(
        'winds-aloft-speed-labels', 'text-color', ['get', 'color']);

    // Temperature labels below speed
    await map.style.addLayer(SymbolLayer(
      id: 'winds-aloft-temp-labels',
      sourceId: srcId,
      textField: '{tempLabel}',
      textSize: 10.0,
      textColor: const Color(0xFFAABBCC).toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.0,
      textOffset: [0.0, 3.0],
      textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      textAllowOverlap: true,
      textIgnorePlacement: true,
    ));
  }

  static Future<void> _setupBreadcrumbLayers(MapboxMap map, String srcId) async {
    // Black border line for contrast
    await map.style.addLayer(LineLayer(
      id: 'breadcrumb-border',
      sourceId: srcId,
      lineWidth: 4.0,
      lineOpacity: 0.5,
      lineColor: Colors.black.toARGB32(),
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));
    // Cyan trail line
    await map.style.addLayer(LineLayer(
      id: 'breadcrumb-line',
      sourceId: srcId,
      lineWidth: 2.5,
      lineOpacity: 0.85,
      lineColor: const Color(0xFF00E5FF).toARGB32(),
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));
  }

  static Future<void> _setupOwnPositionLayers(MapboxMap map, String srcId) async {
    // Outer pulsing ring
    await map.style.addLayer(CircleLayer(
      id: 'own-position-outer',
      sourceId: srcId,
      circleRadius: 18.0,
      circleColor: const Color(0x334A90D9).toARGB32(),
      circleStrokeWidth: 2.0,
      circleStrokeColor: const Color(0xFF4A90D9).toARGB32(),
      circlePitchAlignment: CirclePitchAlignment.MAP,
    ));

    // Solid blue center dot
    await map.style.addLayer(CircleLayer(
      id: 'own-position-dot',
      sourceId: srcId,
      circleRadius: 7.0,
      circleColor: const Color(0xFF4A90D9).toARGB32(),
      circleStrokeWidth: 2.0,
      circleStrokeColor: Colors.white.toARGB32(),
      circlePitchAlignment: CirclePitchAlignment.MAP,
    ));

    // Heading cone (triangle) — only shown when groundspeed > 5kt
    // Uses a symbol layer with a triangle icon rotated by track
    await map.style.addLayer(SymbolLayer(
      id: 'own-position-heading',
      sourceId: srcId,
      iconImage: 'own-position-cone',
      iconSize: 0.5,
      iconRotate: 0.0,
      iconRotationAlignment: IconRotationAlignment.MAP,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      iconOffset: [0.0, -40.0],
      filter: ['>', ['get', 'groundspeed'], 5],
    ));
    await map.style.setStyleLayerProperty(
        'own-position-heading', 'icon-rotate', ['get', 'track']);
  }

  static Future<void> _setupStreamlineLayers(MapboxMap map, String srcId) async {
    // Color-coded lines for animated particle trails (color driven by speed)
    await map.style.addLayer(LineLayer(
      id: 'wind-streamlines-line',
      sourceId: srcId,
      lineWidth: 1.5,
      lineOpacity: 0.7,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
      lineColor: const Color(0xFF4CAF50).toARGB32(),
    ));
    // Data-driven color from feature properties
    await map.style.setStyleLayerProperty(
        'wind-streamlines-line', 'line-color', ['get', 'color']);
  }

  /// Register the heading cone image for the own-position overlay.
  Future<void> _registerConeImage(MapboxMap map) async {
    try {
      const w = 32;
      const h = 48;
      final pixels = Uint8List(w * h * 4);
      // Draw a filled triangle pointing up (blue #4A90D9)
      for (int y = 0; y < h; y++) {
        final progress = y / h;
        final halfWidth = (progress * w / 2).round();
        final cx = w ~/ 2;
        for (int x = cx - halfWidth; x <= cx + halfWidth; x++) {
          if (x < 0 || x >= w) continue;
          final idx = (y * w + x) * 4;
          pixels[idx] = 0x4A;     // R
          pixels[idx + 1] = 0x90; // G
          pixels[idx + 2] = 0xD9; // B
          pixels[idx + 3] = 0xDD; // A
        }
      }
      final mbxImage = MbxImage(width: w, height: h, data: pixels);
      await map.style.addStyleImage(
        'own-position-cone', 2.0, mbxImage,
        false, <ImageStretches>[], <ImageStretches>[], null,
      );
    } catch (e) {
      debugPrint('[EFB] Failed to register cone image: $e');
    }
  }

  /// Register a chevron/triangle image for traffic targets, registered as SDF
  /// so it can be dynamically colored by threat level via icon-color.
  Future<void> _registerTrafficChevron(MapboxMap map) async {
    try {
      const w = 24;
      const h = 24;
      final pixels = Uint8List(w * h * 4);
      // Draw a filled triangle pointing up: tip at (12, 2),
      // base corners at (2, 22) and (22, 22)
      for (int y = 2; y < h - 2; y++) {
        final progress = (y - 2) / (h - 4);
        final halfWidth = (progress * (w / 2 - 2)).round();
        final cx = w ~/ 2;
        for (int x = cx - halfWidth; x <= cx + halfWidth; x++) {
          if (x < 0 || x >= w) continue;
          final idx = (y * w + x) * 4;
          pixels[idx] = 0xFF;     // R
          pixels[idx + 1] = 0xFF; // G
          pixels[idx + 2] = 0xFF; // B
          pixels[idx + 3] = 0xFF; // A
        }
      }
      final mbxImage = MbxImage(width: w, height: h, data: pixels);
      await map.style.addStyleImage(
        'traffic-chevron', 2.0, mbxImage,
        true, // SDF — allows dynamic icon-color
        <ImageStretches>[], <ImageStretches>[], null,
      );
    } catch (e) {
      debugPrint('[EFB] Failed to register traffic chevron image: $e');
    }
  }

  /// Register VFR chart-style airport symbol images for use by SymbolLayer.
  Future<void> _registerAirportSymbolImages(MapboxMap map) async {
    try {
      final symbols = await AirportSymbolRenderer.generateAllSymbols(scale: 2.0);
      debugPrint('[EFB] Registering ${symbols.length} airport symbol images...');
      int registered = 0;
      for (final entry in symbols.entries) {
        final name = entry.key;
        final img = entry.value;
        final expectedSize = img.width * img.height * 4;
        if (img.data.length != expectedSize) {
          debugPrint('[EFB] SKIP airport symbol $name: data size ${img.data.length} != expected $expectedSize');
          continue;
        }
        try {
          final mbxImage = MbxImage(
            width: img.width,
            height: img.height,
            data: Uint8List.fromList(img.data),
          );
          await map.style.addStyleImage(
            name, 2.0, mbxImage, false, <ImageStretches>[], <ImageStretches>[], null,
          );
          registered++;
        } catch (e) {
          debugPrint('[EFB] Failed to register airport symbol $name: $e');
        }
      }
      debugPrint('[EFB] Successfully registered $registered/${symbols.length} airport symbol images');
    } catch (e) {
      debugPrint('[EFB] Failed to generate airport symbol images: $e');
    }
  }

  /// Register wind barb images into the Mapbox style for use by SymbolLayer.
  Future<void> _registerWindBarbImages(MapboxMap map) async {
    try {
      final barbs = await WindBarbRenderer.generateAllBarbs(scale: 2.0);
      debugPrint('[EFB] Registering ${barbs.length} wind barb images...');
      int registered = 0;
      for (final entry in barbs.entries) {
        final name = entry.key;
        final img = entry.value;
        final expectedSize = img.width * img.height * 4;
        if (img.data.length != expectedSize) {
          debugPrint('[EFB] SKIP $name: data size ${img.data.length} != expected $expectedSize');
          continue;
        }
        try {
          final mbxImage = MbxImage(
            width: img.width,
            height: img.height,
            data: Uint8List.fromList(img.data),
          );
          await map.style.addStyleImage(
              name, 2.0, mbxImage, false, <ImageStretches>[], <ImageStretches>[], null);
          registered++;
        } catch (e) {
          debugPrint('[EFB] Failed to register barb image $name: $e');
        }
      }
      debugPrint('[EFB] Successfully registered $registered/${barbs.length} barb images');
    } catch (e) {
      debugPrint('[EFB] Failed to generate wind barb images: $e');
    }
  }

  /// Register the wind arrow SDF image for directional indicators.
  Future<void> _registerWindArrowImage(MapboxMap map) async {
    try {
      final arrow = WindArrowRenderer.generateArrow(scale: 2.0);
      final mbxImage = MbxImage(
        width: arrow.width,
        height: arrow.height,
        data: Uint8List.fromList(arrow.data),
      );
      await map.style.addStyleImage(
        'wind-arrow',
        2.0,
        mbxImage,
        true, // SDF — allows dynamic icon-color
        <ImageStretches>[],
        <ImageStretches>[],
        null,
      );
      debugPrint('[EFB] Registered wind-arrow SDF image');
    } catch (e) {
      debugPrint('[EFB] Failed to register wind arrow image: $e');
    }
  }

  /// Add a hillshade terrain layer (rendered below wind layers, above base map).
  Future<void> _addHillshadeLayer(MapboxMap map) async {
    try {
      await map.style.addSource(RasterDemSource(
        id: 'mapbox-terrain-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 514,
      ));
      await map.style.addLayer(HillshadeLayer(
        id: 'hillshade-terrain',
        sourceId: 'mapbox-terrain-dem',
        hillshadeExaggeration: 0.5,
        hillshadeShadowColor: const Color(0xFF1A1A2E).toARGB32(),
        hillshadeIlluminationDirection: 315.0,
        visibility: Visibility.NONE,
      ));
      // Set initial opacity low
      await map.style.setStyleLayerProperty(
          'hillshade-terrain', 'hillshade-illumination-anchor', 'viewport');
    } catch (e) {
      debugPrint('Failed to add hillshade layer: $e');
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
      onScrollListener: (_) {
        widget.controller?.onUserPanned?.call();
      },
    );
  }
}

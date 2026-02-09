import 'dart:math';

import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../maps/widgets/map_view.dart' show mapboxAccessToken;

class PlatformRouteMapView extends StatefulWidget {
  /// List of route points, each with: identifier, latitude, longitude, isEndpoint.
  final List<Map<String, dynamic>> routePoints;

  const PlatformRouteMapView({
    super.key,
    required this.routePoints,
  });

  @override
  State<PlatformRouteMapView> createState() => _PlatformRouteMapViewState();
}

class _PlatformRouteMapViewState extends State<PlatformRouteMapView> {
  MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    map.gestures.updateSettings(GesturesSettings(
      scrollEnabled: false,
      pinchToZoomEnabled: false,
      doubleTapToZoomInEnabled: false,
      doubleTouchToZoomOutEnabled: false,
      rotateEnabled: false,
    ));
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    final map = _mapboxMap;
    if (map == null) return;

    await _addRouteAndMarkers(map);
    await _fitCamera(map);
  }

  Future<void> _addRouteAndMarkers(MapboxMap map) async {
    final points = widget.routePoints;
    if (points.length < 2) return;

    // Build the route line coordinates from all points
    final coords = points
        .map((p) => '[${p['longitude']},${p['latitude']}]')
        .join(',');

    final lineGeoJson =
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coords]}}';

    try {
      await map.style.addSource(
        GeoJsonSource(id: 'route-source', data: lineGeoJson),
      );
      await map.style.addLayer(LineLayer(
        id: 'route-line',
        sourceId: 'route-source',
        lineColor: AppColors.routeMagenta.toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.9,
      ));
    } catch (e) {
      debugPrint('FlightRouteMap: Failed to add route line: $e');
    }

    // Airport/waypoint markers
    final endpointFeatures = <String>[];
    final waypointFeatures = <String>[];

    for (final p in points) {
      final id = p['identifier'] as String;
      final lng = p['longitude'] as double;
      final lat = p['latitude'] as double;
      final isEndpoint = p['isEndpoint'] as bool;

      final feature =
          '{"type":"Feature","geometry":{"type":"Point","coordinates":[$lng,$lat]},"properties":{"id":"$id"}}';

      if (isEndpoint) {
        endpointFeatures.add(feature);
      } else {
        waypointFeatures.add(feature);
      }
    }

    // Endpoint markers (departure/destination) — larger
    if (endpointFeatures.isNotEmpty) {
      try {
        await map.style.addSource(
          GeoJsonSource(
            id: 'route-endpoints-source',
            data:
                '{"type":"FeatureCollection","features":[${endpointFeatures.join(',')}]}',
          ),
        );

        await map.style.addLayer(CircleLayer(
          id: 'route-endpoints-circles',
          sourceId: 'route-endpoints-source',
          circleRadius: 5.0,
          circleColor: Colors.white.toARGB32(),
          circleStrokeWidth: 1.5,
          circleStrokeColor: AppColors.routeMagenta.toARGB32(),
        ));

        await map.style.addLayer(SymbolLayer(
          id: 'route-endpoints-labels',
          sourceId: 'route-endpoints-source',
          textField: '{id}',
          textSize: 11.0,
          textColor: Colors.white.toARGB32(),
          textHaloColor: Colors.black.toARGB32(),
          textHaloWidth: 1.5,
          textOffset: [0.0, -1.5],
          textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
        ));
      } catch (e) {
        debugPrint('FlightRouteMap: Failed to add endpoint markers: $e');
      }
    }

    // Intermediate waypoint markers — smaller
    if (waypointFeatures.isNotEmpty) {
      try {
        await map.style.addSource(
          GeoJsonSource(
            id: 'route-waypoints-source',
            data:
                '{"type":"FeatureCollection","features":[${waypointFeatures.join(',')}]}',
          ),
        );

        await map.style.addLayer(CircleLayer(
          id: 'route-waypoints-circles',
          sourceId: 'route-waypoints-source',
          circleRadius: 3.0,
          circleColor: Colors.white.toARGB32(),
          circleStrokeWidth: 1.0,
          circleStrokeColor: AppColors.routeMagenta.toARGB32(),
        ));

        await map.style.addLayer(SymbolLayer(
          id: 'route-waypoints-labels',
          sourceId: 'route-waypoints-source',
          textField: '{id}',
          textSize: 9.0,
          textColor: Colors.white.toARGB32(),
          textHaloColor: Colors.black.toARGB32(),
          textHaloWidth: 1.0,
          textOffset: [0.0, -1.3],
          textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
        ));
      } catch (e) {
        debugPrint('FlightRouteMap: Failed to add waypoint markers: $e');
      }
    }
  }

  Future<void> _fitCamera(MapboxMap map) async {
    final points = widget.routePoints;
    if (points.isEmpty) return;

    double minLng = double.infinity, maxLng = -double.infinity;
    double minLat = double.infinity, maxLat = -double.infinity;

    for (final p in points) {
      final lng = p['longitude'] as double;
      final lat = p['latitude'] as double;
      minLng = min(minLng, lng);
      maxLng = max(maxLng, lng);
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
    }

    try {
      final bounds = CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      );

      final camera = await map.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
        null, null, null, null,
      );

      await map.setCamera(camera);
    } catch (e) {
      debugPrint('FlightRouteMap: Failed to fit camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.routePoints;
    if (points.isEmpty) return const SizedBox.shrink();

    // Center on midpoint of all route points
    double sumLat = 0, sumLng = 0;
    for (final p in points) {
      sumLat += p['latitude'] as double;
      sumLng += p['longitude'] as double;
    }
    final centerLat = sumLat / points.length;
    final centerLng = sumLng / points.length;

    // Build a stable key from all identifiers
    final keyStr = points.map((p) => p['identifier']).join('-');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: MapWidget(
          key: ValueKey('route-map-$keyStr'),
          styleUri: MapboxStyles.SATELLITE_STREETS,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(centerLng, centerLat)),
            zoom: 7.0,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
        ),
      ),
    );
  }
}

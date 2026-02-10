import 'dart:math';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/config/app_config.dart';

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
  late final String _viewType;
  late final String _mapVar;

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _viewType = 'efb-route-map-$ts';
    _mapVar = 'efbRouteMap_$ts';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container =
          web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'route-map-container-$viewId';
      container.style
        ..width = '100%'
        ..height = '100%'
        ..position = 'relative';

      Future.delayed(const Duration(milliseconds: 100), () {
        _initMapboxJs(container.id);
      });

      return container;
    });
  }

  void _initMapboxJs(String containerId) {
    final points = widget.routePoints;
    if (points.length < 2) return;

    // Center on midpoint
    double sumLat = 0, sumLng = 0;
    for (final p in points) {
      sumLat += p['latitude'] as double;
      sumLng += p['longitude'] as double;
    }
    final centerLng = sumLng / points.length;
    final centerLat = sumLat / points.length;

    // Build the coordinates array for the route line
    final coordsJs = points
        .map((p) => '[${p['longitude']},${p['latitude']}]')
        .join(',');

    // Build endpoint features
    final endpointFeaturesJs = points
        .where((p) => p['isEndpoint'] == true)
        .map((p) =>
            "{ type: 'Feature', geometry: { type: 'Point', coordinates: [${p['longitude']},${p['latitude']}] }, properties: { id: '${p['identifier']}' } }")
        .join(',');

    // Build waypoint features (non-endpoints)
    final waypointFeaturesJs = points
        .where((p) => p['isEndpoint'] != true)
        .map((p) =>
            "{ type: 'Feature', geometry: { type: 'Point', coordinates: [${p['longitude']},${p['latitude']}] }, properties: { id: '${p['identifier']}' } }")
        .join(',');

    // Compute bounds
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

    final script = '''
      (function() {
        if (typeof mapboxgl === 'undefined') {
          console.error('Mapbox GL JS not loaded');
          return;
        }
        mapboxgl.accessToken = '${AppConfig.mapboxToken}';

        var map = new mapboxgl.Map({
          container: '$containerId',
          style: 'mapbox://styles/mapbox/satellite-streets-v12',
          center: [$centerLng, $centerLat],
          zoom: 7,
          interactive: false
        });

        window.$_mapVar = map;

        map.on('load', function() {
          // Route line through all waypoints
          map.addSource('route', {
            type: 'geojson',
            data: {
              type: 'Feature',
              geometry: {
                type: 'LineString',
                coordinates: [$coordsJs]
              }
            }
          });

          map.addLayer({
            id: 'route-line',
            type: 'line',
            source: 'route',
            paint: {
              'line-color': '#FF00FF',
              'line-width': 3,
              'line-opacity': 0.9
            }
          });

          // Endpoint markers (departure/destination)
          map.addSource('route-endpoints', {
            type: 'geojson',
            data: {
              type: 'FeatureCollection',
              features: [$endpointFeaturesJs]
            }
          });

          map.addLayer({
            id: 'route-endpoints-circles',
            type: 'circle',
            source: 'route-endpoints',
            paint: {
              'circle-radius': 5,
              'circle-color': '#ffffff',
              'circle-stroke-width': 1.5,
              'circle-stroke-color': '#FF00FF'
            }
          });

          map.addLayer({
            id: 'route-endpoints-labels',
            type: 'symbol',
            source: 'route-endpoints',
            layout: {
              'text-field': ['get', 'id'],
              'text-size': 11,
              'text-offset': [0, -1.5],
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
            },
            paint: {
              'text-color': '#ffffff',
              'text-halo-color': '#000000',
              'text-halo-width': 1.5
            }
          });

          // Intermediate waypoint markers (if any)
          ${waypointFeaturesJs.isNotEmpty ? """
          map.addSource('route-waypoints', {
            type: 'geojson',
            data: {
              type: 'FeatureCollection',
              features: [$waypointFeaturesJs]
            }
          });

          map.addLayer({
            id: 'route-waypoints-circles',
            type: 'circle',
            source: 'route-waypoints',
            paint: {
              'circle-radius': 3,
              'circle-color': '#ffffff',
              'circle-stroke-width': 1,
              'circle-stroke-color': '#FF00FF'
            }
          });

          map.addLayer({
            id: 'route-waypoints-labels',
            type: 'symbol',
            source: 'route-waypoints',
            layout: {
              'text-field': ['get', 'id'],
              'text-size': 9,
              'text-offset': [0, -1.3],
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
            },
            paint: {
              'text-color': '#ffffff',
              'text-halo-color': '#000000',
              'text-halo-width': 1.0
            }
          });
          """ : ''}

          // Fit bounds
          map.fitBounds(
            [
              [$minLng, $minLat],
              [$maxLng, $maxLat]
            ],
            { padding: 24, duration: 0 }
          );
        });
      })();
    ''';

    _evalJs(script);
  }

  void _evalJs(String script) {
    final scriptEl =
        web.document.createElement('script') as web.HTMLScriptElement;
    scriptEl.text = script;
    web.document.body!.append(scriptEl);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}

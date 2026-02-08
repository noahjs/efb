import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../maps/widgets/map_view.dart' show mapboxAccessToken;

class PlatformRouteMapView extends StatefulWidget {
  final String depId;
  final double depLat;
  final double depLng;
  final String destId;
  final double destLat;
  final double destLng;

  const PlatformRouteMapView({
    super.key,
    required this.depId,
    required this.depLat,
    required this.depLng,
    required this.destId,
    required this.destLat,
    required this.destLng,
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
    final depLng = widget.depLng;
    final depLat = widget.depLat;
    final destLng = widget.destLng;
    final destLat = widget.destLat;
    final centerLng = (depLng + destLng) / 2;
    final centerLat = (depLat + destLat) / 2;

    final script = '''
      (function() {
        if (typeof mapboxgl === 'undefined') {
          console.error('Mapbox GL JS not loaded');
          return;
        }
        mapboxgl.accessToken = '$mapboxAccessToken';

        var map = new mapboxgl.Map({
          container: '$containerId',
          style: 'mapbox://styles/mapbox/satellite-streets-v12',
          center: [$centerLng, $centerLat],
          zoom: 7,
          interactive: false
        });

        window.$_mapVar = map;

        map.on('load', function() {
          // Route line
          map.addSource('route', {
            type: 'geojson',
            data: {
              type: 'Feature',
              geometry: {
                type: 'LineString',
                coordinates: [
                  [$depLng, $depLat],
                  [$destLng, $destLat]
                ]
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

          // Airport markers
          map.addSource('route-airports', {
            type: 'geojson',
            data: {
              type: 'FeatureCollection',
              features: [
                { type: 'Feature', geometry: { type: 'Point', coordinates: [$depLng, $depLat] }, properties: { id: '${widget.depId}' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [$destLng, $destLat] }, properties: { id: '${widget.destId}' } }
              ]
            }
          });

          map.addLayer({
            id: 'route-airports-circles',
            type: 'circle',
            source: 'route-airports',
            paint: {
              'circle-radius': 5,
              'circle-color': '#ffffff',
              'circle-stroke-width': 1.5,
              'circle-stroke-color': '#FF00FF'
            }
          });

          map.addLayer({
            id: 'route-airports-labels',
            type: 'symbol',
            source: 'route-airports',
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

          // Fit bounds
          map.fitBounds(
            [
              [Math.min($depLng, $destLng), Math.min($depLat, $destLat)],
              [Math.max($depLng, $destLng), Math.max($depLat, $destLat)]
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

import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'map_view.dart' show mapboxAccessToken;

/// Web implementation using Mapbox GL JS directly via HtmlElementView.
class PlatformMapView extends StatefulWidget {
  final String baseLayer;

  const PlatformMapView({super.key, required this.baseLayer});

  @override
  State<PlatformMapView> createState() => _PlatformMapViewState();
}

class _PlatformMapViewState extends State<PlatformMapView> {
  final String _viewType =
      'efb-mapbox-${DateTime.now().millisecondsSinceEpoch}';
  late final String _mapVar;

  static String _styleForLayer(String layer) {
    switch (layer) {
      case 'street':
        return 'mapbox://styles/mapbox/streets-v12';
      case 'vfr':
      case 'satellite':
      default:
        return 'mapbox://styles/mapbox/satellite-streets-v12';
    }
  }

  @override
  void initState() {
    super.initState();
    _mapVar = 'efbMap_${DateTime.now().millisecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container =
          web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'mapbox-container-$viewId';
      container.style
        ..width = '100%'
        ..height = '100%'
        ..position = 'relative';

      // Initialize Mapbox GL JS map after the element is attached
      Future.delayed(const Duration(milliseconds: 100), () {
        _initMapboxJs(container.id);
      });

      return container;
    });
  }

  @override
  void didUpdateWidget(covariant PlatformMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseLayer != widget.baseLayer) {
      _switchStyle();
    }
  }

  void _switchStyle() {
    final style = _styleForLayer(widget.baseLayer);
    final addVfr = widget.baseLayer == 'vfr';
    final script = '''
      (function() {
        var map = window.$_mapVar;
        if (!map) return;
        map.setStyle('$style');
        map.once('style.load', function() {
          ${addVfr ? _vfrTilesJs() : ''}
          ${_airportMarkersJs()}
          ${_routeLineJs()}
        });
      })();
    ''';
    _evalJs(script);
  }

  void _initMapboxJs(String containerId) {
    final style = _styleForLayer(widget.baseLayer);
    final addVfr = widget.baseLayer == 'vfr';
    final script = '''
      (function() {
        if (typeof mapboxgl === 'undefined') {
          console.error('Mapbox GL JS not loaded');
          return;
        }
        mapboxgl.accessToken = '$mapboxAccessToken';

        var map = new mapboxgl.Map({
          container: '$containerId',
          style: '$style',
          center: [-104.8493, 39.5701],
          zoom: 8.5
        });

        window.$_mapVar = map;

        map.on('load', function() {
          ${addVfr ? _vfrTilesJs() : ''}
          ${_airportMarkersJs()}
          ${_routeLineJs()}

          // Navigation controls
          map.addControl(new mapboxgl.NavigationControl(), 'bottom-right');
        });
      })();
    ''';

    _evalJs(script);
  }

  static String _vfrTilesJs() {
    return '''
          var vfrCharts = ['Denver', 'Cheyenne', 'Albuquerque', 'Salt_Lake_City'];
          vfrCharts.forEach(function(chart) {
            map.addSource('vfr-' + chart, {
              type: 'raster',
              tiles: ['http://localhost:3001/api/tiles/vfr-sectional/' + chart + '/{z}/{x}/{y}.png'],
              tileSize: 256,
              minzoom: 5,
              maxzoom: 11,
              attribution: 'FAA VFR Sectional: ' + chart
            });

            map.addLayer({
              id: 'vfr-layer-' + chart,
              type: 'raster',
              source: 'vfr-' + chart,
              paint: {
                'raster-opacity': 0.85
              }
            });
          });
    ''';
  }

  static String _airportMarkersJs() {
    return '''
          map.addSource('airports', {
            type: 'geojson',
            data: {
              type: 'FeatureCollection',
              features: [
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-104.8493, 39.5701] }, properties: { id: 'KAPA', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-105.1172, 39.9088] }, properties: { id: 'KBJC', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-104.6737, 39.8561] }, properties: { id: 'KDEN', category: 'mvfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-105.0113, 40.4518] }, properties: { id: 'KFNL', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-104.7006, 38.8058] }, properties: { id: 'KCFO', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-105.2256, 40.0393] }, properties: { id: 'KBDU', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-105.0481, 40.0102] }, properties: { id: 'KEIK', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-105.1633, 40.1637] }, properties: { id: 'KLMO', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-104.6332, 40.4374] }, properties: { id: 'KGXY', category: 'vfr' } },
                { type: 'Feature', geometry: { type: 'Point', coordinates: [-104.7517, 39.7017] }, properties: { id: 'KBKF', category: 'vfr' } }
              ]
            }
          });

          map.addLayer({
            id: 'airport-dots',
            type: 'circle',
            source: 'airports',
            paint: {
              'circle-radius': 7,
              'circle-color': [
                'match', ['get', 'category'],
                'vfr', '#00C853',
                'mvfr', '#2196F3',
                'ifr', '#FF1744',
                'lifr', '#E040FB',
                '#00C853'
              ],
              'circle-stroke-width': 1.5,
              'circle-stroke-color': 'rgba(255,255,255,0.5)'
            }
          });

          map.addLayer({
            id: 'airport-labels',
            type: 'symbol',
            source: 'airports',
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
    ''';
  }

  static String _routeLineJs() {
    return '''
          map.addSource('route', {
            type: 'geojson',
            data: {
              type: 'Feature',
              geometry: {
                type: 'LineString',
                coordinates: [
                  [-104.8493, 39.5701],
                  [-105.15, 39.95],
                  [-105.70, 40.55]
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
    ''';
  }

  void _evalJs(String script) {
    final scriptEl =
        web.document.createElement('script') as web.HTMLScriptElement;
    scriptEl.text = script;
    web.document.body!.append(scriptEl);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

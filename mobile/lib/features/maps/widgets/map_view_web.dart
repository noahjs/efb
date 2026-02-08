import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'map_view.dart' show EfbMapController, MapBounds, mapboxAccessToken;

/// Web implementation using Mapbox GL JS directly via HtmlElementView.
class PlatformMapView extends StatefulWidget {
  final String baseLayer;
  final bool showFlightCategory;
  final bool interactive;
  final ValueChanged<String>? onAirportTapped;
  final ValueChanged<MapBounds>? onBoundsChanged;
  final List<Map<String, dynamic>> airports;
  final List<List<double>> routeCoordinates;
  final EfbMapController? controller;

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
  });

  @override
  State<PlatformMapView> createState() => _PlatformMapViewState();
}

@JS('_efbOnAirportTap')
external set _onAirportTapJs(JSFunction? fn);

@JS('_efbOnBoundsChanged')
external set _onBoundsChangedJs(JSFunction? fn);

class _PlatformMapViewState extends State<PlatformMapView> {
  final String _viewType =
      'efb-mapbox-${DateTime.now().millisecondsSinceEpoch}';
  late final String _mapVar;
  bool _mapReady = false;
  final List<web.HTMLScriptElement> _injectedScripts = [];

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
    _registerCallbacks();
    _bindController();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container =
          web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'mapbox-container-$viewId';
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

  void _bindController() {
    widget.controller?.onZoomIn = () {
      _evalJs('''
        (function() {
          var map = window.$_mapVar;
          if (map) map.zoomIn();
        })();
      ''');
    };
    widget.controller?.onZoomOut = () {
      _evalJs('''
        (function() {
          var map = window.$_mapVar;
          if (map) map.zoomOut();
        })();
      ''');
    };
  }

  @override
  void dispose() {
    widget.controller?.onZoomIn = null;
    widget.controller?.onZoomOut = null;
    _onAirportTapJs = null;
    _onBoundsChangedJs = null;
    // Remove the Mapbox map instance
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (map) { map.remove(); }
        delete window.$_mapVar;
      })();
    ''');
    // Clean up injected script tags
    for (final script in _injectedScripts) {
      script.remove();
    }
    _injectedScripts.clear();
    super.dispose();
  }

  void _registerCallbacks() {
    _onAirportTapJs = ((JSString id) {
      widget.onAirportTapped?.call(id.toDart);
    }).toJS;

    _onBoundsChangedJs =
        ((JSNumber minLng, JSNumber minLat, JSNumber maxLng, JSNumber maxLat) {
      widget.onBoundsChanged?.call((
        minLat: minLat.toDartDouble,
        maxLat: maxLat.toDartDouble,
        minLng: minLng.toDartDouble,
        maxLng: maxLng.toDartDouble,
      ));
    }).toJS;
  }

  @override
  void didUpdateWidget(covariant PlatformMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep JS callbacks in sync with the latest widget callbacks
    _registerCallbacks();
    if (oldWidget.baseLayer != widget.baseLayer) {
      _switchLayer(oldWidget.baseLayer, widget.baseLayer);
    }
    if (oldWidget.showFlightCategory != widget.showFlightCategory) {
      _setFlightCategoryMode(widget.showFlightCategory);
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
  }

  void _setInteractive(bool enabled) {
    final method = enabled ? 'enable' : 'disable';
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map) return;
        map.scrollZoom.$method();
        map.dragPan.$method();
        map.doubleClickZoom.$method();
        map.touchZoomRotate.$method();
      })();
    ''');
  }

  void _setFlightCategoryMode(bool enabled) {
    final circleRadius = enabled ? 7 : 5;
    final circleColor = enabled
        ? "['match', ['get', 'category'], 'VFR', '#00C853', 'MVFR', '#2196F3', 'IFR', '#FF1744', 'LIFR', '#E040FB', '#888888']"
        : "'#888888'";
    final strokeWidth = enabled ? 1.5 : 0.5;
    final labelsVisibility = enabled ? 'visible' : 'none';

    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map || !map.getLayer('airport-dots')) return;
        map.setPaintProperty('airport-dots', 'circle-radius', $circleRadius);
        map.setPaintProperty('airport-dots', 'circle-color', $circleColor);
        map.setPaintProperty('airport-dots', 'circle-stroke-width', $strokeWidth);
        if (map.getLayer('airport-labels')) {
          map.setLayoutProperty('airport-labels', 'visibility', '$labelsVisibility');
        }
      })();
    ''');
  }

  void _updateAirportsSource() {
    if (!_mapReady) return;
    final geojson = _buildAirportsGeoJson(widget.airports);
    // Escape for JS string embedding
    final escaped = geojson.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map) return;
        var src = map.getSource('airports');
        if (src) {
          src.setData(JSON.parse('$escaped'));
        }
      })();
    ''');
  }

  static String _buildAirportsGeoJson(List<Map<String, dynamic>> airports) {
    final features = airports.where((a) {
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

  void _switchLayer(String oldLayer, String newLayer) {
    final oldStyle = _styleForLayer(oldLayer);
    final newStyle = _styleForLayer(newLayer);
    final vfrVisibility = newLayer == 'vfr' ? 'visible' : 'none';

    if (oldStyle != newStyle) {
      // Different Mapbox base style — full swap, re-add all layers after load
      _evalJs('''
        (function() {
          var map = window.$_mapVar;
          if (!map) return;
          map.setStyle('$newStyle');
          map.once('style.load', function() {
            ${_vfrTilesJs(vfrVisibility)}
            ${_airportLayersJs(widget.showFlightCategory)}
            ${_routeLayerJs()}
            ${_airportClickHandlersJs()}
            ${_boundsHandlerJs()}
          });
        })();
      ''');
      // After style reload, push current data into the fresh sources
      Future.delayed(const Duration(milliseconds: 200), () {
        _updateAirportsSource();
        _updateRouteSource();
      });
    } else {
      // Same Mapbox style — just toggle VFR layer visibility
      _evalJs('''
        (function() {
          var map = window.$_mapVar;
          if (!map) return;
          var vfrCharts = ['Denver', 'Cheyenne', 'Albuquerque', 'Salt_Lake_City'];
          vfrCharts.forEach(function(chart) {
            if (map.getLayer('vfr-layer-' + chart)) {
              map.setLayoutProperty('vfr-layer-' + chart, 'visibility', '$vfrVisibility');
            }
          });
        })();
      ''');
    }
  }

  void _initMapboxJs(String containerId) {
    final style = _styleForLayer(widget.baseLayer);
    final vfrVisibility = widget.baseLayer == 'vfr' ? 'visible' : 'none';
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
          ${_vfrTilesJs(vfrVisibility)}
          ${_airportLayersJs(widget.showFlightCategory)}
          ${_routeLayerJs()}
          ${_airportClickHandlersJs()}
          ${_boundsHandlerJs()}

          // Navigation controls
          map.addControl(new mapboxgl.NavigationControl(), 'bottom-right');

          // Fire initial bounds
          var b = map.getBounds();
          if (window._efbOnBoundsChanged) {
            window._efbOnBoundsChanged(b.getWest(), b.getSouth(), b.getEast(), b.getNorth());
          }
        });
      })();
    ''';

    _evalJs(script);
    // Mark map ready after init script runs (with margin for load event)
    Future.delayed(const Duration(milliseconds: 500), () {
      _mapReady = true;
    });
  }

  static String _vfrTilesJs(String visibility) {
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
              layout: {
                'visibility': '$visibility'
              },
              paint: {
                'raster-opacity': 0.85
              }
            });
          });
    ''';
  }

  /// Creates the airports GeoJSON source (empty initially) and the dot/label layers.
  /// When [showFlightCategory] is true, dots are colored by METAR category and labels shown.
  /// When false, dots are small gray circles with no labels.
  static String _airportLayersJs(bool showFlightCategory) {
    final circleRadius = showFlightCategory ? 7 : 5;
    final circleColor = showFlightCategory
        ? "['match', ['get', 'category'], 'VFR', '#00C853', 'MVFR', '#2196F3', 'IFR', '#FF1744', 'LIFR', '#E040FB', '#888888']"
        : "'#888888'";
    final strokeWidth = showFlightCategory ? 1.5 : 0.5;
    final labelsVisibility = showFlightCategory ? 'visible' : 'none';

    return '''
          map.addSource('airports', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });

          map.addLayer({
            id: 'airport-dots',
            type: 'circle',
            source: 'airports',
            paint: {
              'circle-radius': $circleRadius,
              'circle-color': $circleColor,
              'circle-stroke-width': $strokeWidth,
              'circle-stroke-color': 'rgba(255,255,255,0.5)'
            }
          });

          map.addLayer({
            id: 'airport-labels',
            type: 'symbol',
            source: 'airports',
            layout: {
              'visibility': '$labelsVisibility',
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

  static String _routeLayerJs() {
    return '''
          map.addSource('route', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });

          map.addLayer({
            id: 'route-line',
            type: 'line',
            source: 'route',
            paint: {
              'line-color': '#00FFFF',
              'line-width': 3,
              'line-opacity': 0.9
            }
          });
    ''';
  }

  void _updateRouteSource() {
    if (!_mapReady) return;
    final geojson = _buildRouteGeoJson(widget.routeCoordinates);
    final escaped = geojson.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map) return;
        var src = map.getSource('route');
        if (src) {
          src.setData(JSON.parse('$escaped'));
        }
      })();
    ''');
  }

  static String _buildRouteGeoJson(List<List<double>> coords) {
    if (coords.length < 2) {
      return '{"type":"FeatureCollection","features":[]}';
    }
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
          'properties': {},
        }
      ],
    });
  }

  static String _airportClickHandlersJs() {
    return '''
          map.on('click', 'airport-dots', function(e) {
            if (e.features && e.features.length > 0) {
              var id = e.features[0].properties.id;
              if (window._efbOnAirportTap) {
                window._efbOnAirportTap(id);
              }
            }
          });

          map.on('mouseenter', 'airport-dots', function() {
            map.getCanvas().style.cursor = 'pointer';
          });

          map.on('mouseleave', 'airport-dots', function() {
            map.getCanvas().style.cursor = '';
          });
    ''';
  }

  static String _boundsHandlerJs() {
    return '''
          map.on('moveend', function() {
            var b = map.getBounds();
            if (window._efbOnBoundsChanged) {
              window._efbOnBoundsChanged(b.getWest(), b.getSouth(), b.getEast(), b.getNorth());
            }
          });
    ''';
  }

  void _evalJs(String script) {
    final scriptEl =
        web.document.createElement('script') as web.HTMLScriptElement;
    scriptEl.text = script;
    web.document.body!.append(scriptEl);
    _injectedScripts.add(scriptEl);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../../core/config/app_config.dart';
import 'map_view.dart' show EfbMapController, MapBounds;

/// Web implementation using Mapbox GL JS directly via HtmlElementView.
class PlatformMapView extends StatefulWidget {
  final String baseLayer;
  final bool showFlightCategory;
  final bool interactive;
  final ValueChanged<String>? onAirportTapped;
  final ValueChanged<Map<String, dynamic>>? onPirepTapped;
  final ValueChanged<MapBounds>? onBoundsChanged;
  final void Function(double lat, double lng, List<Map<String, dynamic>> aeroFeatures)? onMapLongPressed;
  final List<Map<String, dynamic>> airports;
  final List<List<double>> routeCoordinates;
  final EfbMapController? controller;
  final Map<String, dynamic>? airspaceGeoJson;
  final Map<String, dynamic>? airwayGeoJson;
  final Map<String, dynamic>? artccGeoJson;

  /// GeoJSON overlays keyed by source ID (e.g. 'tfrs', 'advisories', 'pireps').
  final Map<String, Map<String, dynamic>?> overlays;

  const PlatformMapView({
    super.key,
    required this.baseLayer,
    this.showFlightCategory = false,
    this.interactive = true,
    this.onAirportTapped,
    this.onPirepTapped,
    this.onBoundsChanged,
    this.onMapLongPressed,
    this.airports = const [],
    this.routeCoordinates = const [],
    this.controller,
    this.airspaceGeoJson,
    this.airwayGeoJson,
    this.artccGeoJson,
    this.overlays = const {},
  });

  @override
  State<PlatformMapView> createState() => _PlatformMapViewState();
}

@JS('_efbOnAirportTap')
external set _onAirportTapJs(JSFunction? fn);

@JS('_efbOnPirepTap')
external set _onPirepTapJs(JSFunction? fn);

@JS('_efbOnBoundsChanged')
external set _onBoundsChangedJs(JSFunction? fn);

@JS('_efbOnMapLongPress')
external set _onMapLongPressJs(JSFunction? fn);

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
      case 'dark':
        return 'mapbox://styles/mapbox/dark-v11';
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
    widget.controller?.onFlyTo = (double lat, double lng, {double? zoom}) {
      final z = zoom ?? 11;
      _evalJs('''
        (function() {
          var map = window.$_mapVar;
          if (map) map.flyTo({center: [$lng, $lat], zoom: $z, duration: 1000});
        })();
      ''');
    };
  }

  @override
  void dispose() {
    widget.controller?.onZoomIn = null;
    widget.controller?.onZoomOut = null;
    widget.controller?.onFlyTo = null;
    _onAirportTapJs = null;
    _onBoundsChangedJs = null;
    _onMapLongPressJs = null;
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

    _onPirepTapJs = ((JSString propsJson) {
      final props = Map<String, dynamic>.from(
          jsonDecode(propsJson.toDart) as Map);
      widget.onPirepTapped?.call(props);
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

    _onMapLongPressJs =
        ((JSNumber lat, JSNumber lng, JSString propsJson, JSString layersJson) {
      final propsList = (jsonDecode(propsJson.toDart) as List)
          .map((s) => Map<String, dynamic>.from(jsonDecode(s as String) as Map))
          .toList();
      final layersList =
          (jsonDecode(layersJson.toDart) as List).cast<String>();

      const layerTypeMap = {
        'airspace-fill': 'airspace',
        'artcc-lines': 'artcc',
        'airway-lines': 'airway',
        'tfr-fill': 'tfr',
        'advisory-fill': 'advisory',
      };

      for (var i = 0; i < propsList.length; i++) {
        propsList[i]['_layerType'] =
            layerTypeMap[layersList[i]] ?? layersList[i];
      }

      widget.onMapLongPressed?.call(
        lat.toDartDouble,
        lng.toDartDouble,
        propsList,
      );
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
    if (oldWidget.airspaceGeoJson != widget.airspaceGeoJson) {
      _updateAeroSource('airspaces', widget.airspaceGeoJson);
    }
    if (oldWidget.airwayGeoJson != widget.airwayGeoJson) {
      _updateAeroSource('airways', widget.airwayGeoJson);
    }
    if (oldWidget.artccGeoJson != widget.artccGeoJson) {
      _updateAeroSource('artcc', widget.artccGeoJson);
    }
    // Update generic overlays
    final allKeys = {...oldWidget.overlays.keys, ...widget.overlays.keys};
    for (final key in allKeys) {
      if (oldWidget.overlays[key] != widget.overlays[key]) {
        _updateOverlaySource(key, widget.overlays[key]);
      }
    }
    // Toggle hillshade visibility with winds aloft overlay
    final hadWinds = oldWidget.overlays.containsKey('winds-aloft');
    final hasWinds = widget.overlays.containsKey('winds-aloft');
    if (hadWinds != hasWinds) {
      _setHillshadeVisibility(hasWinds);
    }
  }

  void _setHillshadeVisibility(bool visible) {
    final vis = visible ? 'visible' : 'none';
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map || !map.getLayer('hillshade-terrain')) return;
        map.setLayoutProperty('hillshade-terrain', 'visibility', '$vis');
      })();
    ''');
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
      final id = a['icao_identifier'] ?? a['identifier'] ?? '';
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
            ${_aeronauticalLayersJs()}
            ${_airportLayersJs(widget.showFlightCategory)}
            ${_routeLayerJs()}
            ${_overlayLayersJs()}
            ${_airportClickHandlersJs()}
            ${_longPressHandlerJs()}
            ${_boundsHandlerJs()}
          });
        })();
      ''');
      // After style reload, push current data into the fresh sources
      Future.delayed(const Duration(milliseconds: 200), () {
        _updateAirportsSource();
        _updateRouteSource();
        _updateAeroSource('airspaces', widget.airspaceGeoJson);
        _updateAeroSource('airways', widget.airwayGeoJson);
        _updateAeroSource('artcc', widget.artccGeoJson);
        for (final key in widget.overlays.keys) {
          _updateOverlaySource(key, widget.overlays[key]);
        }
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
        mapboxgl.accessToken = '${AppConfig.mapboxToken}';

        var map = new mapboxgl.Map({
          container: '$containerId',
          style: '$style',
          center: [-104.8493, 39.5701],
          zoom: 8.5
        });

        window.$_mapVar = map;

        map.on('load', function() {
          ${_vfrTilesJs(vfrVisibility)}
          ${_aeronauticalLayersJs()}
          ${_airportLayersJs(widget.showFlightCategory)}
          ${_routeLayerJs()}
          ${_overlayLayersJs()}
          ${_airportClickHandlersJs()}
          ${_longPressHandlerJs()}
          ${_boundsHandlerJs()}

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
      // Push any overlay data that arrived before map was ready
      for (final key in widget.overlays.keys) {
        _updateOverlaySource(key, widget.overlays[key]);
      }
    });
  }

  static String _vfrTilesJs(String visibility) {
    return '''
          var vfrCharts = ['Denver', 'Cheyenne', 'Albuquerque', 'Salt_Lake_City'];
          vfrCharts.forEach(function(chart) {
            map.addSource('vfr-' + chart, {
              type: 'raster',
              tiles: ['${AppConfig.apiBaseUrl}/api/tiles/vfr-sectional/' + chart + '/{z}/{x}/{y}.png'],
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
            id: 'route-line-border',
            type: 'line',
            source: 'route',
            paint: {
              'line-color': '#000000',
              'line-width': 5,
              'line-opacity': 0.4
            }
          });

          map.addLayer({
            id: 'route-line',
            type: 'line',
            source: 'route',
            filter: ['!=', ['get', 'leg'], 'first'],
            paint: {
              'line-color': '#66FFFF',
              'line-width': 3,
              'line-opacity': 0.85
            }
          });

          map.addLayer({
            id: 'route-line-first',
            type: 'line',
            source: 'route',
            filter: ['==', ['get', 'leg'], 'first'],
            paint: {
              'line-color': '#FF00FF',
              'line-width': 3,
              'line-opacity': 0.85
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
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  /// Creates aeronautical GeoJSON sources and layers (ARTCC, airways, airspaces).
  static String _aeronauticalLayersJs() {
    return '''
          map.addSource('artcc', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'artcc-lines',
            type: 'line',
            source: 'artcc',
            paint: {
              'line-color': '#999999',
              'line-width': 1,
              'line-opacity': 0.6,
              'line-dasharray': [4, 4]
            }
          });

          map.addSource('airways', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'airway-lines',
            type: 'line',
            source: 'airways',
            paint: {
              'line-color': '#64B5F6',
              'line-width': 1,
              'line-opacity': 0.7
            }
          });

          map.addSource('airspaces', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'airspace-fill',
            type: 'fill',
            source: 'airspaces',
            paint: {
              'fill-color': '#2196F3',
              'fill-opacity': 0.1
            }
          });
          map.addLayer({
            id: 'airspace-border',
            type: 'line',
            source: 'airspaces',
            paint: {
              'line-color': '#2196F3',
              'line-width': 2,
              'line-opacity': 0.8
            }
          });
    ''';
  }

  void _updateAeroSource(String sourceId, Map<String, dynamic>? data) {
    if (!_mapReady) return;
    final geojson = data != null
        ? jsonEncode(data)
        : '{"type":"FeatureCollection","features":[]}';
    final escaped = geojson.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map) return;
        var src = map.getSource('$sourceId');
        if (src) {
          src.setData(JSON.parse('$escaped'));
        }
      })();
    ''');
  }

  /// Creates GeoJSON sources and layers for all generic overlays.
  static String _overlayLayersJs() {
    return '''
          // ── TFR overlay ──
          map.addSource('tfrs', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'tfr-fill',
            type: 'fill',
            source: 'tfrs',
            paint: {
              'fill-color': ['coalesce', ['get', 'color'], '#FF5252'],
              'fill-opacity': 0.15
            }
          });
          map.addLayer({
            id: 'tfr-outline',
            type: 'line',
            source: 'tfrs',
            paint: {
              'line-color': ['coalesce', ['get', 'color'], '#FF5252'],
              'line-width': 2,
              'line-opacity': 0.8
            }
          });

          // ── Advisory (AIR/SIGMET/CWA) overlay ──
          map.addSource('advisories', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'advisory-fill',
            type: 'fill',
            source: 'advisories',
            paint: {
              'fill-color': ['coalesce', ['get', 'color'], '#B0B4BC'],
              'fill-opacity': 0.2
            }
          });
          map.addLayer({
            id: 'advisory-outline',
            type: 'line',
            source: 'advisories',
            paint: {
              'line-color': ['coalesce', ['get', 'color'], '#B0B4BC'],
              'line-width': 2
            }
          });

          // ── PIREP overlay ──
          map.addSource('pireps', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'pirep-dots',
            type: 'circle',
            source: 'pireps',
            paint: {
              'circle-radius': 6,
              'circle-color': ['coalesce', ['get', 'color'], '#B0B4BC'],
              'circle-stroke-width': 1.5,
              'circle-stroke-color': 'rgba(255,255,255,0.3)'
            }
          });
          map.addLayer({
            id: 'pirep-urgent-ring',
            type: 'circle',
            source: 'pireps',
            filter: ['==', 'isUrgent', true],
            paint: {
              'circle-radius': 10,
              'circle-color': 'transparent',
              'circle-stroke-width': 2,
              'circle-stroke-color': '#FF5252'
            }
          });

          // ── METAR pill background images (stretchable rounded rects) ──
          (function() {
            var pills = {
              'pill-green': '#4CAF50',
              'pill-yellow': '#FFC107',
              'pill-orange': '#FF9800',
              'pill-red': '#FF5252',
              'pill-blue': '#2196F3',
              'pill-ltblue': '#29B6F6',
              'pill-purple': '#E040FB'
            };
            var w = 28, h = 20, r = 6;
            Object.keys(pills).forEach(function(name) {
              var canvas = document.createElement('canvas');
              canvas.width = w;
              canvas.height = h;
              var ctx = canvas.getContext('2d');
              ctx.fillStyle = pills[name];
              ctx.beginPath();
              ctx.moveTo(r, 0);
              ctx.lineTo(w - r, 0);
              ctx.arcTo(w, 0, w, r, r);
              ctx.lineTo(w, h - r);
              ctx.arcTo(w, h, w - r, h, r);
              ctx.lineTo(r, h);
              ctx.arcTo(0, h, 0, h - r, r);
              ctx.lineTo(0, r);
              ctx.arcTo(0, 0, r, 0, r);
              ctx.closePath();
              ctx.fill();
              var imageData = ctx.getImageData(0, 0, w, h);
              map.addImage(name, {width: w, height: h, data: imageData.data}, {
                stretchX: [[r, w - r]],
                stretchY: [[r, h - r]],
                content: [r, 2, w - r, h - 2]
              });
            });
          })();

          // ── METAR-derived overlay ──
          map.addSource('metar-overlay', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          // Pill labels for all METAR overlay types (rendered first, below arrows)
          map.addLayer({
            id: 'metar-overlay-pills',
            type: 'symbol',
            source: 'metar-overlay',
            layout: {
              'icon-image': ['match', ['get', 'color'],
                '#4CAF50', 'pill-green',
                '#FFC107', 'pill-yellow',
                '#FF9800', 'pill-orange',
                '#FF5252', 'pill-red',
                '#2196F3', 'pill-blue',
                '#29B6F6', 'pill-ltblue',
                '#E040FB', 'pill-purple',
                'pill-green'],
              'icon-text-fit': 'both',
              'icon-text-fit-padding': [1, 4, 1, 4],
              'text-field': ['get', 'label'],
              'text-size': 11,
              'text-font': ['DIN Pro Bold', 'Arial Unicode MS Bold'],
              'text-allow-overlap': true,
              'text-ignore-placement': true,
              'icon-allow-overlap': true,
              'icon-ignore-placement': true,
              'text-offset': [0, 0]
            },
            paint: {
              'text-color': '#ffffff',
              'text-halo-color': 'rgba(0,0,0,0.15)',
              'text-halo-width': 0.5
            }
          });
          // ── Traffic overlay ──
          map.addSource('traffic', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          // Leader lines (target → heads)
          map.addLayer({
            id: 'traffic-leader-lines',
            type: 'line',
            source: 'traffic',
            filter: ['==', ['get', 'featureType'], 'leader'],
            paint: {
              'line-color': ['match', ['get', 'threat'],
                'resolution', '#FF5252',
                'alert', '#FF5252',
                'proximate', '#FFC107',
                '#AAAAAA'],
              'line-width': 2.5,
              'line-opacity': 0.9
            }
          });
          // 5-min head markers
          map.addLayer({
            id: 'traffic-head-5min',
            type: 'circle',
            source: 'traffic',
            filter: ['all',
              ['==', ['get', 'featureType'], 'head'],
              ['==', ['get', 'head_interval'], 300]
            ],
            paint: {
              'circle-radius': 2.5,
              'circle-color': ['match', ['get', 'threat'],
                'resolution', '#FF5252',
                'alert', '#FF5252',
                'proximate', '#FFC107',
                '#FFFFFF'],
              'circle-opacity': 0.85,
              'circle-stroke-width': 0.5,
              'circle-stroke-color': 'rgba(255,255,255,0.9)'
            }
          });
          // 2-min head markers
          map.addLayer({
            id: 'traffic-head-2min',
            type: 'circle',
            source: 'traffic',
            filter: ['all',
              ['==', ['get', 'featureType'], 'head'],
              ['==', ['get', 'head_interval'], 120]
            ],
            paint: {
              'circle-radius': 3,
              'circle-color': ['match', ['get', 'threat'],
                'resolution', '#FF5252',
                'alert', '#FF5252',
                'proximate', '#FFC107',
                '#FFFFFF'],
              'circle-opacity': 0.9,
              'circle-stroke-width': 0.5,
              'circle-stroke-color': 'rgba(255,255,255,0.9)'
            }
          });
          // Head altitude labels
          map.addLayer({
            id: 'traffic-head-alt-labels',
            type: 'symbol',
            source: 'traffic',
            filter: ['==', ['get', 'featureType'], 'head'],
            layout: {
              'text-field': ['get', 'alt_tag'],
              'text-size': 8,
              'text-offset': [0, 1.2],
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
            },
            paint: {
              'text-color': 'rgba(255,255,255,0.7)',
              'text-halo-color': '#000000',
              'text-halo-width': 1
            }
          });
          // Traffic chevron image (SDF for dynamic coloring)
          (function() {
            var size = 24;
            var canvas = document.createElement('canvas');
            canvas.width = size;
            canvas.height = size;
            var ctx = canvas.getContext('2d');
            ctx.fillStyle = '#FFFFFF';
            ctx.beginPath();
            ctx.moveTo(size / 2, 2);
            ctx.lineTo(size - 2, size - 2);
            ctx.lineTo(2, size - 2);
            ctx.closePath();
            ctx.fill();
            var imageData = ctx.getImageData(0, 0, size, size);
            map.addImage('traffic-chevron', {width: size, height: size, data: imageData.data}, {sdf: true});
          })();
          // Traffic target chevrons — directional markers
          map.addLayer({
            id: 'traffic-dots',
            type: 'symbol',
            source: 'traffic',
            filter: ['==', ['get', 'featureType'], 'target'],
            layout: {
              'icon-image': 'traffic-chevron',
              'icon-size': 0.9,
              'icon-rotate': ['get', 'track'],
              'icon-rotation-alignment': 'map',
              'icon-allow-overlap': true,
              'icon-ignore-placement': true
            },
            paint: {
              'icon-color': ['match', ['get', 'threat'],
                'resolution', '#FF5252',
                'alert', '#FF5252',
                'proximate', '#FFC107',
                '#FFFFFF']
            }
          });
          // Callsign labels
          map.addLayer({
            id: 'traffic-labels',
            type: 'symbol',
            source: 'traffic',
            filter: ['==', ['get', 'featureType'], 'target'],
            layout: {
              'text-field': ['get', 'callsign'],
              'text-size': 10,
              'text-offset': [0, -1.8],
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
            },
            paint: {
              'text-color': '#ffffff',
              'text-halo-color': '#000000',
              'text-halo-width': 1
            }
          });
          // Altitude tags
          map.addLayer({
            id: 'traffic-alt-labels',
            type: 'symbol',
            source: 'traffic',
            filter: ['==', ['get', 'featureType'], 'target'],
            layout: {
              'text-field': ['get', 'alt_tag'],
              'text-size': 9,
              'text-offset': [0, 1.2],
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
            },
            paint: {
              'text-color': '#ffffff',
              'text-halo-color': '#000000',
              'text-halo-width': 1
            }
          });

          // ── Own Position overlay ──
          map.addSource('own-position', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'own-position-outer',
            type: 'circle',
            source: 'own-position',
            paint: {
              'circle-radius': 18,
              'circle-color': 'rgba(74, 144, 217, 0.2)',
              'circle-stroke-width': 2,
              'circle-stroke-color': '#4A90D9',
              'circle-pitch-alignment': 'map'
            }
          });
          map.addLayer({
            id: 'own-position-dot',
            type: 'circle',
            source: 'own-position',
            paint: {
              'circle-radius': 7,
              'circle-color': '#4A90D9',
              'circle-stroke-width': 2,
              'circle-stroke-color': '#FFFFFF',
              'circle-pitch-alignment': 'map'
            }
          });

          // ── Hillshade terrain ──
          map.addSource('mapbox-terrain-dem', {
            type: 'raster-dem',
            url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
            tileSize: 512
          });
          map.addLayer({
            id: 'hillshade-terrain',
            type: 'hillshade',
            source: 'mapbox-terrain-dem',
            layout: { 'visibility': 'none' },
            paint: {
              'hillshade-exaggeration': 0.5,
              'hillshade-shadow-color': '#1A1A2E',
              'hillshade-illumination-direction': 315,
              'hillshade-illumination-anchor': 'viewport'
            }
          });

          // ── Wind barb image generation ──
          (function() {
            var speeds = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80];
            speeds.forEach(function(kt) {
              var name = kt < 3 ? 'barb-calm' : 'barb-' + kt;
              var size = 64;
              var canvas = document.createElement('canvas');
              canvas.width = size;
              canvas.height = size;
              var ctx = canvas.getContext('2d');
              var color;
              if (kt < 15) color = '#4CAF50';
              else if (kt < 30) color = '#FFC107';
              else if (kt < 50) color = '#FF9800';
              else color = '#F44336';
              ctx.strokeStyle = color;
              ctx.fillStyle = color;
              ctx.lineWidth = 2;
              ctx.lineCap = 'round';
              var cx = size / 2, cy = size / 2;
              if (kt < 3) {
                ctx.beginPath();
                ctx.arc(cx, cy, 6, 0, Math.PI * 2);
                ctx.stroke();
              } else {
                var staffTop = cy - 20, staffBottom = cy + 8;
                ctx.beginPath();
                ctx.moveTo(cx, staffBottom);
                ctx.lineTo(cx, staffTop);
                ctx.stroke();
                var remaining = kt;
                var pennants = Math.floor(remaining / 50); remaining -= pennants * 50;
                var fullBarbs = Math.floor(remaining / 10); remaining -= fullBarbs * 10;
                var halfBarbs = Math.floor(remaining / 5);
                var y = staffTop, barbLen = 12, spacing = 4;
                for (var i = 0; i < pennants; i++) {
                  ctx.beginPath();
                  ctx.moveTo(cx, y);
                  ctx.lineTo(cx + barbLen, y + 3);
                  ctx.lineTo(cx, y + 6);
                  ctx.fill();
                  y += 7;
                }
                for (var i = 0; i < fullBarbs; i++) {
                  ctx.beginPath();
                  ctx.moveTo(cx, y);
                  ctx.lineTo(cx + barbLen, y - 4);
                  ctx.stroke();
                  y += spacing;
                }
                for (var i = 0; i < halfBarbs; i++) {
                  if (pennants === 0 && fullBarbs === 0 && i === 0) y += spacing;
                  ctx.beginPath();
                  ctx.moveTo(cx, y);
                  ctx.lineTo(cx + barbLen * 0.55, y - 3);
                  ctx.stroke();
                  y += spacing;
                }
              }
              var imageData = ctx.getImageData(0, 0, size, size);
              map.addImage(name, {width: size, height: size, data: imageData.data});
            });
          })();

          // ── Winds Aloft overlay (barbs + labels) ──
          map.addSource('winds-aloft', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'winds-aloft-barbs',
            type: 'symbol',
            source: 'winds-aloft',
            layout: {
              'icon-image': ['get', 'barbIcon'],
              'icon-size': 0.8,
              'icon-rotate': ['get', 'rotation'],
              'icon-rotation-alignment': 'map',
              'icon-allow-overlap': true,
              'icon-ignore-placement': true
            }
          });
          map.addLayer({
            id: 'winds-aloft-labels',
            type: 'symbol',
            source: 'winds-aloft',
            layout: {
              'text-field': ['get', 'label'],
              'text-size': 10,
              'text-offset': [0, 2],
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular'],
              'text-allow-overlap': true,
              'text-ignore-placement': true
            },
            paint: {
              'text-color': ['coalesce', ['get', 'color'], '#4CAF50'],
              'text-halo-color': '#000000',
              'text-halo-width': 1
            }
          });

          // ── Wind Streamlines overlay ──
          map.addSource('wind-streamlines', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'wind-streamlines-line',
            type: 'line',
            source: 'wind-streamlines',
            paint: {
              'line-color': ['coalesce', ['get', 'color'], '#4CAF50'],
              'line-width': 2,
              'line-opacity': 0.7
            },
            layout: {
              'line-cap': 'round',
              'line-join': 'round'
            }
          });
    ''';
  }

  void _updateOverlaySource(String key, Map<String, dynamic>? data) {
    if (!_mapReady) {
      debugPrint('[EFB] _updateOverlaySource($key): map not ready');
      return;
    }
    final featureCount = data != null
        ? (data['features'] as List?)?.length ?? 0
        : 0;
    debugPrint('[EFB] _updateOverlaySource($key): $featureCount features');
    final geojson = data != null
        ? jsonEncode(data)
        : '{"type":"FeatureCollection","features":[]}';
    final escaped = geojson.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map) { console.log('[EFB] overlay update: no map'); return; }
        var src = map.getSource('$key');
        if (src) {
          try {
            var data = JSON.parse('$escaped');
            src.setData(data);
            console.log('[EFB] overlay $key updated: ' + (data.features ? data.features.length : 0) + ' features');
          } catch(e) {
            console.error('[EFB] overlay $key JSON parse error:', e);
          }
        } else {
          console.log('[EFB] overlay $key: source not found');
        }
      })();
    ''');
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

          map.on('click', 'pirep-dots', function(e) {
            if (e.features && e.features.length > 0) {
              var props = JSON.stringify(e.features[0].properties);
              if (window._efbOnPirepTap) {
                window._efbOnPirepTap(props);
              }
            }
          });

          map.on('mouseenter', 'pirep-dots', function() {
            map.getCanvas().style.cursor = 'pointer';
          });

          map.on('mouseleave', 'pirep-dots', function() {
            map.getCanvas().style.cursor = '';
          });
    ''';
  }

  static String _longPressHandlerJs() {
    return '''
          map.on('contextmenu', function(e) {
            var pad = 20;
            var box = [[e.point.x - pad, e.point.y - pad], [e.point.x + pad, e.point.y + pad]];
            var layers = ['airspace-fill', 'artcc-lines', 'airway-lines', 'tfr-fill', 'advisory-fill'];
            var existingLayers = layers.filter(function(l) { return map.getLayer(l); });
            var allFeatures = existingLayers.length > 0
              ? map.queryRenderedFeatures(box, { layers: existingLayers })
              : [];
            // Deduplicate by id + layer (advisories use hazard+tag+time)
            var seen = {};
            var features = allFeatures.filter(function(f) {
              var key;
              if (f.layer.id === 'advisory-fill') {
                var p = f.properties;
                key = 'advisory:' + (p.hazard || '') + '|' + (p.tag || p.seriesId || p.cwsu || '') + '|' + (p.validTime || p.validTimeFrom || '');
              } else {
                key = f.layer.id + ':' + (f.properties.id || f.properties.name || '');
              }
              if (seen[key]) return false;
              seen[key] = true;
              return true;
            });
            var props = features.map(function(f) { return JSON.stringify(f.properties); });
            var layerIds = features.map(function(f) { return f.layer.id; });
            if (window._efbOnMapLongPress) {
              window._efbOnMapLongPress(
                e.lngLat.lat, e.lngLat.lng,
                JSON.stringify(props), JSON.stringify(layerIds)
              );
            }
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

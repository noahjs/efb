import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../../core/config/app_config.dart';
import 'airport_symbol_renderer.dart';
import 'map_view.dart' show EfbMapController, MapBounds;

/// Web implementation using Mapbox GL JS directly via HtmlElementView.
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
  /// GeoJSON overlays keyed by source ID (e.g. 'tfrs', 'airspaces', 'pireps').
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

@JS('_efbOnMapTap')
external set _onMapTapJs(JSFunction? fn);

@JS('_efbOnAirportTap')
external set _onAirportTapJs(JSFunction? fn);

@JS('_efbOnNavaidTap')
external set _onNavaidTapJs(JSFunction? fn);

@JS('_efbOnFixTap')
external set _onFixTapJs(JSFunction? fn);

@JS('_efbOnPirepTap')
external set _onPirepTapJs(JSFunction? fn);

@JS('_efbOnBoundsChanged')
external set _onBoundsChangedJs(JSFunction? fn);

@JS('_efbOnMapLongPress')
external set _onMapLongPressJs(JSFunction? fn);

@JS('_efbOnUserPanned')
external set _onUserPannedJs(JSFunction? fn);

class _PlatformMapViewState extends State<PlatformMapView> {
  final String _viewType =
      'efb-mapbox-${DateTime.now().millisecondsSinceEpoch}';
  late final String _mapVar;
  bool _mapReady = false;
  bool _particlesRunning = false;
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

    // Follow mode: smooth camera tracking for ownship
    widget.controller?.onFollowTo = (double lat, double lng, {double bearing = 0}) {
      _evalJs('''
        (function() {
          var map = window.$_mapVar;
          if (map) map.flyTo({center: [$lng, $lat], bearing: $bearing, duration: 400});
        })();
      ''');
    };

    // onUserPanned is set by maps_screen.dart — no-op here, callback via JS

    // Particle animation via JS
    widget.controller?.onUpdateParticleField = (windField,
        {required minLat, required maxLat, required minLng, required maxLng}) {
      final fieldJson = jsonEncode(windField);
      final escaped = fieldJson.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      _evalJs('''
        (function() {
          if (!window._efbParticles) return;
          var field = JSON.parse('$escaped');
          window._efbParticles.updateWindField(field, $minLat, $maxLat, $minLng, $maxLng);
        })();
      ''');
    };
    widget.controller?.onStartParticles = () {
      _particlesRunning = true;
      _evalJs('''
        (function() {
          if (window._efbParticles && !window._efbParticles.running) {
            window._efbParticles.start('$_mapVar');
          }
        })();
      ''');
    };
    widget.controller?.onStopParticles = () {
      _particlesRunning = false;
      _evalJs('''
        (function() {
          if (window._efbParticles) window._efbParticles.stop();
        })();
      ''');
    };
    widget.controller?.getParticlesRunning = () => _particlesRunning;
  }

  @override
  void dispose() {
    widget.controller?.onZoomIn = null;
    widget.controller?.onZoomOut = null;
    widget.controller?.onFlyTo = null;
    widget.controller?.onFollowTo = null;
    _onAirportTapJs = null;
    _onBoundsChangedJs = null;
    _onMapLongPressJs = null;
    _onUserPannedJs = null;
    // Stop particle animation
    if (_particlesRunning) {
      _evalJs('if (window._efbParticles) window._efbParticles.stop();');
      _particlesRunning = false;
    }
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
    _onMapTapJs = (() {
      widget.onMapTapped?.call();
    }).toJS;

    _onAirportTapJs = ((JSString id) {
      widget.onAirportTapped?.call(id.toDart);
    }).toJS;

    _onNavaidTapJs = ((JSString id) {
      widget.onNavaidTapped?.call(id.toDart);
    }).toJS;

    _onFixTapJs = ((JSString id) {
      widget.onFixTapped?.call(id.toDart);
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

    _onUserPannedJs = (() {
      widget.controller?.onUserPanned?.call();
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
    // Update overlays (including aeronautical sub-layers)
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
    final haloVisibility = enabled ? 'visible' : 'none';
    final labelsVisibility = enabled ? 'visible' : 'none';

    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (!map) return;
        if (map.getLayer('airport-cat-halos')) {
          map.setLayoutProperty('airport-cat-halos', 'visibility', '$haloVisibility');
        }
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

  /// Creates VFR chart-style airport symbol images, the airports GeoJSON
  /// source, and symbol/circle layers for rendering.
  static String _airportLayersJs(bool showFlightCategory) {
    final labelsVisibility = showFlightCategory ? 'visible' : 'none';
    final haloVisibility = showFlightCategory ? 'visible' : 'none';

    return '''
          // ── Generate VFR chart-style airport symbol images ──
          (function() {
            var size = 80;
            var magenta = 'rgb(200,50,220)';
            var blue = 'rgb(50,100,235)';
            var red = 'rgb(220,70,70)';
            var gray = 'rgb(150,150,150)';

            function drawHardSurface(color, filled, serviced) {
              var canvas = document.createElement('canvas');
              canvas.width = size; canvas.height = size;
              var ctx = canvas.getContext('2d');
              var cx = size/2, cy = size/2;
              var radius = size * 0.30;
              var barHalf = size * 0.42;
              var lw = Math.max(2, Math.round(size * 0.06));
              var tickLen = Math.round(size * 0.12);

              // White fill for readability
              ctx.fillStyle = filled ? 'rgba(255,255,255,1)' : 'rgba(255,255,255,0.7)';
              ctx.beginPath();
              ctx.arc(cx, cy, radius - lw, 0, Math.PI * 2);
              ctx.fill();

              // Circle outline
              ctx.strokeStyle = color;
              ctx.lineWidth = lw;
              ctx.beginPath();
              ctx.arc(cx, cy, radius - lw/2, 0, Math.PI * 2);
              ctx.stroke();

              // Runway bar
              ctx.fillStyle = color;
              ctx.fillRect(cx - barHalf, cy - lw/2, barHalf * 2, lw);

              // Tick marks at N/S/E/W
              if (serviced) {
                ctx.fillRect(cx - lw/2, cy - radius - tickLen, lw, tickLen);
                ctx.fillRect(cx - lw/2, cy + radius + 1, lw, tickLen);
                ctx.fillRect(cx + radius + 1, cy - lw/2, tickLen, lw);
                ctx.fillRect(cx - radius - tickLen, cy - lw/2, tickLen, lw);
              }

              return ctx.getImageData(0, 0, size, size);
            }

            function drawSoftSurface(color, serviced) {
              var canvas = document.createElement('canvas');
              canvas.width = size; canvas.height = size;
              var ctx = canvas.getContext('2d');
              var cx = size/2, cy = size/2;
              var radius = size * 0.22;
              var lw = Math.max(2, Math.round(size * 0.06));
              var tickLen = Math.round(size * 0.12);

              ctx.fillStyle = color;
              ctx.beginPath();
              ctx.arc(cx, cy, radius, 0, Math.PI * 2);
              ctx.fill();

              if (serviced) {
                ctx.fillRect(cx - lw/2, cy - radius - tickLen, lw, tickLen);
                ctx.fillRect(cx - lw/2, cy + radius + 1, lw, tickLen);
                ctx.fillRect(cx + radius + 1, cy - lw/2, tickLen, lw);
                ctx.fillRect(cx - radius - tickLen, cy - lw/2, tickLen, lw);
              }

              return ctx.getImageData(0, 0, size, size);
            }

            function drawLetterSymbol(color, letter) {
              var canvas = document.createElement('canvas');
              canvas.width = size; canvas.height = size;
              var ctx = canvas.getContext('2d');
              var cx = size/2, cy = size/2;
              var radius = size * 0.30;
              var lw = Math.max(2, Math.round(size * 0.06));

              ctx.fillStyle = 'rgba(255,255,255,0.8)';
              ctx.beginPath();
              ctx.arc(cx, cy, radius - lw, 0, Math.PI * 2);
              ctx.fill();

              ctx.strokeStyle = color;
              ctx.lineWidth = lw;
              ctx.beginPath();
              ctx.arc(cx, cy, radius - lw/2, 0, Math.PI * 2);
              ctx.stroke();

              ctx.fillStyle = color;
              ctx.font = 'bold ' + Math.round(radius * 1.1) + 'px sans-serif';
              ctx.textAlign = 'center';
              ctx.textBaseline = 'middle';
              ctx.fillText(letter, cx, cy + 1);

              return ctx.getImageData(0, 0, size, size);
            }

            function drawSeaplane(color) {
              var canvas = document.createElement('canvas');
              canvas.width = size; canvas.height = size;
              var ctx = canvas.getContext('2d');
              var cx = size/2, cy = size/2;
              var radius = size * 0.30;
              var lw = Math.max(2, Math.round(size * 0.06));

              ctx.fillStyle = 'rgba(255,255,255,0.8)';
              ctx.beginPath();
              ctx.arc(cx, cy, radius - lw, 0, Math.PI * 2);
              ctx.fill();

              ctx.strokeStyle = color;
              ctx.lineWidth = lw;
              ctx.beginPath();
              ctx.arc(cx, cy, radius - lw/2, 0, Math.PI * 2);
              ctx.stroke();

              // Anchor: vertical stem + crossbar + ring + flukes
              var stemH = radius * 0.6;
              ctx.strokeStyle = color;
              ctx.lineWidth = lw;
              ctx.beginPath();
              ctx.moveTo(cx, cy - stemH);
              ctx.lineTo(cx, cy + stemH);
              ctx.stroke();

              var crossW = stemH * 0.5;
              var crossY = cy - stemH * 0.4;
              ctx.beginPath();
              ctx.moveTo(cx - crossW, crossY);
              ctx.lineTo(cx + crossW, crossY);
              ctx.stroke();

              // Ring at top
              ctx.beginPath();
              ctx.arc(cx, cy - stemH - 3, 3, 0, Math.PI * 2);
              ctx.stroke();

              // Flukes at bottom
              ctx.beginPath();
              ctx.arc(cx, cy + stemH + crossW * 0.6, crossW, Math.PI, 0);
              ctx.stroke();

              return ctx.getImageData(0, 0, size, size);
            }

            var symbols = {
              'apt-hard-t-s':    drawHardSurface(blue, true, true),
              'apt-hard-t-ns':   drawHardSurface(blue, true, false),
              'apt-hard-nt-s':   drawHardSurface(magenta, false, true),
              'apt-hard-nt-ns':  drawHardSurface(magenta, false, false),
              'apt-soft-s':      drawSoftSurface(magenta, true),
              'apt-soft-ns':     drawSoftSurface(magenta, false),
              'apt-private':     drawLetterSymbol(magenta, 'R'),
              'apt-heliport':    drawLetterSymbol(magenta, 'H'),
              'apt-seaplane':    drawSeaplane(magenta),
              'apt-military-s':  drawHardSurface(red, true, true),
              'apt-military-ns': drawHardSurface(red, true, false),
              'apt-unknown':     drawSoftSurface(gray, false)
            };

            Object.keys(symbols).forEach(function(name) {
              var img = symbols[name];
              map.addImage(name, {width: img.width, height: img.height, data: img.data});
            });
            console.log('[EFB] Registered ' + Object.keys(symbols).length + ' airport symbol images');
          })();

          map.addSource('airports', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });

          // Flight category halo circles — behind symbols, hidden by default
          map.addLayer({
            id: 'airport-cat-halos',
            type: 'circle',
            source: 'airports',
            layout: { 'visibility': '$haloVisibility' },
            paint: {
              'circle-radius': 12,
              'circle-color': ['match', ['get', 'category'],
                'VFR', '#00C853', 'MVFR', '#2196F3',
                'IFR', '#FF1744', 'LIFR', '#E040FB',
                'rgba(0,0,0,0)'],
              'circle-opacity': 0.35,
              'circle-stroke-width': 2,
              'circle-stroke-color': ['match', ['get', 'category'],
                'VFR', '#00C853', 'MVFR', '#2196F3',
                'IFR', '#FF1744', 'LIFR', '#E040FB',
                'rgba(0,0,0,0)']
            }
          });

          // VFR chart-style airport symbols — data-driven icon-image
          map.addLayer({
            id: 'airport-dots',
            type: 'symbol',
            source: 'airports',
            layout: {
              'icon-image': ['get', 'symbolType'],
              'icon-size': 0.55,
              'icon-allow-overlap': true,
              'icon-ignore-placement': true
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
              'line-color': '#FFFFFF',
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

  /// Creates GeoJSON sources and layers for all overlays (aeronautical + situational).
  static String _overlayLayersJs() {
    return '''
          // ── Aeronautical layers (rendered beneath situational overlays) ──
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

          // ── Navaids (VOR/VORTAC/NDB/DME/TACAN) ──
          map.addSource('navaids', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });

          // Generate VOR symbol image using Canvas
          (function() {
            var vorSize = 32;
            var vorCanvas = document.createElement('canvas');
            vorCanvas.width = vorSize;
            vorCanvas.height = vorSize;
            var ctx = vorCanvas.getContext('2d');
            var cx = vorSize / 2;
            var cy = vorSize / 2;
            var r = 10;

            // VOR compass rose: hexagonal shape with tick marks
            ctx.strokeStyle = '#3366FF';
            ctx.fillStyle = 'rgba(50, 100, 235, 0.15)';
            ctx.lineWidth = 2;

            // Draw hexagon
            ctx.beginPath();
            for (var i = 0; i < 6; i++) {
              var angle = (Math.PI / 3) * i - Math.PI / 2;
              var px = cx + r * Math.cos(angle);
              var py = cy + r * Math.sin(angle);
              if (i === 0) ctx.moveTo(px, py);
              else ctx.lineTo(px, py);
            }
            ctx.closePath();
            ctx.fill();
            ctx.stroke();

            // Center dot
            ctx.fillStyle = '#3366FF';
            ctx.beginPath();
            ctx.arc(cx, cy, 2, 0, Math.PI * 2);
            ctx.fill();

            // Tick marks at cardinal directions
            var tickLen = 4;
            ctx.beginPath();
            ctx.moveTo(cx, cy - r); ctx.lineTo(cx, cy - r - tickLen);
            ctx.moveTo(cx, cy + r); ctx.lineTo(cx, cy + r + tickLen);
            ctx.moveTo(cx - r, cy); ctx.lineTo(cx - r - tickLen, cy);
            ctx.moveTo(cx + r, cy); ctx.lineTo(cx + r + tickLen, cy);
            ctx.stroke();

            map.addImage('navaid-vor', { width: vorSize, height: vorSize, data: ctx.getImageData(0, 0, vorSize, vorSize).data }, { pixelRatio: 2 });

            // NDB symbol: filled circle with dots radiating outward
            var ndbCanvas = document.createElement('canvas');
            ndbCanvas.width = vorSize;
            ndbCanvas.height = vorSize;
            var nctx = ndbCanvas.getContext('2d');
            // Center filled circle
            nctx.fillStyle = '#9933CC';
            nctx.beginPath();
            nctx.arc(cx, cy, 5, 0, Math.PI * 2);
            nctx.fill();
            // Radiating dots
            nctx.fillStyle = '#9933CC';
            for (var d = 0; d < 12; d++) {
              var da = (Math.PI / 6) * d;
              var dotR = 11;
              nctx.beginPath();
              nctx.arc(cx + dotR * Math.cos(da), cy + dotR * Math.sin(da), 1.2, 0, Math.PI * 2);
              nctx.fill();
            }
            map.addImage('navaid-ndb', { width: vorSize, height: vorSize, data: nctx.getImageData(0, 0, vorSize, vorSize).data }, { pixelRatio: 2 });
          })();

          map.addLayer({
            id: 'navaid-symbols',
            type: 'symbol',
            source: 'navaids',
            layout: {
              'icon-image': ['match', ['get', 'navType'],
                'NDB', 'navaid-ndb',
                'NDB/DME', 'navaid-ndb',
                'MARINE NDB', 'navaid-ndb',
                'navaid-vor'
              ],
              'icon-size': 1,
              'icon-allow-overlap': true,
              'text-field': ['get', 'identifier'],
              'text-size': 10,
              'text-offset': [0, 1.4],
              'text-anchor': 'top',
              'text-optional': true
            },
            paint: {
              'text-color': '#CCCCCC',
              'text-halo-color': '#000000',
              'text-halo-width': 1
            }
          });

          // ── Fixes / Waypoints ──
          map.addSource('fixes', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });

          // Generate cyan triangle fix symbol
          (function() {
            var fixSize = 24;
            var fixCanvas = document.createElement('canvas');
            fixCanvas.width = fixSize;
            fixCanvas.height = fixSize;
            var fctx = fixCanvas.getContext('2d');
            var fcx = fixSize / 2;

            // Equilateral triangle pointing up
            var triH = 10;
            var triW = 11;
            fctx.strokeStyle = '#00E5FF';
            fctx.lineWidth = 1.5;
            fctx.beginPath();
            fctx.moveTo(fcx, fixSize / 2 - triH / 2 - 1);
            fctx.lineTo(fcx - triW / 2, fixSize / 2 + triH / 2 - 1);
            fctx.lineTo(fcx + triW / 2, fixSize / 2 + triH / 2 - 1);
            fctx.closePath();
            fctx.stroke();

            map.addImage('fix-triangle', { width: fixSize, height: fixSize, data: fctx.getImageData(0, 0, fixSize, fixSize).data }, { pixelRatio: 2 });
          })();

          map.addLayer({
            id: 'fix-symbols',
            type: 'symbol',
            source: 'fixes',
            layout: {
              'icon-image': 'fix-triangle',
              'icon-size': 1,
              'icon-allow-overlap': true,
              'text-field': ['get', 'identifier'],
              'text-size': 9,
              'text-offset': [0, 1.2],
              'text-anchor': 'top',
              'text-optional': true
            },
            paint: {
              'text-color': '#AAAAAA',
              'text-halo-color': '#000000',
              'text-halo-width': 1
            }
          });

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
            id: 'pirep-symbols',
            type: 'symbol',
            source: 'pireps',
            layout: {
              'text-field': ['get', 'symbol'],
              'text-size': 16,
              'text-allow-overlap': true,
              'text-ignore-placement': true
            },
            paint: {
              'text-color': ['coalesce', ['get', 'color'], '#B0B4BC']
            }
          });
          map.addLayer({
            id: 'pirep-urgent-ring',
            type: 'circle',
            source: 'pireps',
            filter: ['==', 'isUrgent', true],
            paint: {
              'circle-radius': 12,
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

          // ── Breadcrumb trail overlay ──
          map.addSource('breadcrumb', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });
          map.addLayer({
            id: 'breadcrumb-border',
            type: 'line',
            source: 'breadcrumb',
            paint: {
              'line-color': '#000000',
              'line-width': 4,
              'line-opacity': 0.5
            },
            layout: {
              'line-cap': 'round',
              'line-join': 'round'
            }
          });
          map.addLayer({
            id: 'breadcrumb-line',
            type: 'line',
            source: 'breadcrumb',
            paint: {
              'line-color': '#00E5FF',
              'line-width': 2.5,
              'line-opacity': 0.85
            },
            layout: {
              'line-cap': 'round',
              'line-join': 'round'
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
              'line-width': 1.5,
              'line-opacity': 0.7
            },
            layout: {
              'line-cap': 'round',
              'line-join': 'round'
            }
          });

          // ── Particle animation system ──
          ${_particleSystemJs()}
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
          map.on('click', function() {
            if (window._efbOnMapTap) {
              window._efbOnMapTap();
            }
          });

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

          map.on('click', 'pirep-symbols', function(e) {
            if (e.features && e.features.length > 0) {
              var props = JSON.stringify(e.features[0].properties);
              if (window._efbOnPirepTap) {
                window._efbOnPirepTap(props);
              }
            }
          });

          map.on('mouseenter', 'pirep-symbols', function() {
            map.getCanvas().style.cursor = 'pointer';
          });

          map.on('mouseleave', 'pirep-symbols', function() {
            map.getCanvas().style.cursor = '';
          });

          map.on('click', 'navaid-symbols', function(e) {
            if (e.features && e.features.length > 0) {
              var id = e.features[0].properties.identifier;
              if (id && window._efbOnNavaidTap) {
                window._efbOnNavaidTap(id);
              }
            }
          });

          map.on('mouseenter', 'navaid-symbols', function() {
            map.getCanvas().style.cursor = 'pointer';
          });

          map.on('mouseleave', 'navaid-symbols', function() {
            map.getCanvas().style.cursor = '';
          });

          map.on('click', 'fix-symbols', function(e) {
            if (e.features && e.features.length > 0) {
              var id = e.features[0].properties.identifier;
              if (id && window._efbOnFixTap) {
                window._efbOnFixTap(id);
              }
            }
          });

          map.on('mouseenter', 'fix-symbols', function() {
            map.getCanvas().style.cursor = 'pointer';
          });

          map.on('mouseleave', 'fix-symbols', function() {
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

          map.on('dragstart', function() {
            if (window._efbOnUserPanned) window._efbOnUserPanned();
          });
    ''';
  }

  static String _particleSystemJs() {
    return '''
          (function() {
            if (window._efbParticles) return; // already initialized
            window._efbParticles = {
              windField: [],
              particles: [],
              running: false,
              bounds: {minLat: 0, maxLat: 0, minLng: 0, maxLng: 0},
              mapVar: null,
              timer: null,
              tickCount: 0,
              PARTICLE_COUNT: 200,
              MIN_TRAIL: 6,
              MAX_TRAIL: 20,
              FPS: 12,
              MAX_AGE: 100,

              colorForSpeed: function(speed) {
                if (speed < 15) return '#4CAF50';
                if (speed < 30) return '#FFC107';
                if (speed < 50) return '#FF9800';
                return '#F44336';
              },

              trailLenForSpeed: function(speed) {
                var len = Math.round(this.MIN_TRAIL + (speed / 60) * (this.MAX_TRAIL - this.MIN_TRAIL));
                return Math.max(this.MIN_TRAIL, Math.min(this.MAX_TRAIL, len));
              },

              updateWindField: function(field, minLat, maxLat, minLng, maxLng) {
                this.windField = field;
                this.bounds = {minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng};
              },

              start: function(mapVar) {
                if (this.timer) return;
                if (this.windField.length === 0) { console.log('[EFB] Particles: no wind field'); return; }
                this.mapVar = mapVar;
                this.tickCount = 0;
                this.initParticles();
                var self = this;
                this.timer = setInterval(function() { self.tick(); }, 1000 / self.FPS);
                this.running = true;
                console.log('[EFB] Particle animation started: ' + this.windField.length + ' field points');
              },

              stop: function() {
                if (this.timer) { clearInterval(this.timer); this.timer = null; }
                this.running = false;
                this.particles = [];
                var map = window[this.mapVar];
                if (map) {
                  var src = map.getSource('wind-streamlines');
                  if (src) src.setData({type: 'FeatureCollection', features: []});
                }
                console.log('[EFB] Particle animation stopped');
              },

              initParticles: function() {
                this.particles = [];
                for (var i = 0; i < this.PARTICLE_COUNT; i++) {
                  this.particles.push(this.spawnParticle());
                }
              },

              spawnParticle: function() {
                var b = this.bounds;
                var lat = b.minLat + Math.random() * (b.maxLat - b.minLat);
                var lng = b.minLng + Math.random() * (b.maxLng - b.minLng);
                return {
                  lat: lat, lng: lng,
                  trail: [[lng, lat]],
                  age: 0,
                  speed: 0,
                  maxAge: Math.floor(this.MAX_AGE * 0.6 + Math.random() * this.MAX_AGE * 0.4)
                };
              },

              tick: function() {
                if (this.windField.length === 0) return;
                var map = window[this.mapVar];
                if (!map) return;
                this.tickCount++;
                var b = this.bounds;

                for (var i = 0; i < this.particles.length; i++) {
                  var p = this.particles[i];
                  p.age++;
                  if (p.age >= p.maxAge || p.lat < b.minLat || p.lat > b.maxLat || p.lng < b.minLng || p.lng > b.maxLng) {
                    this.particles[i] = this.spawnParticle();
                    continue;
                  }
                  var wind = this.interpolateWind(p.lat, p.lng);
                  if (!wind || wind.speed < 1) { p.age = p.maxAge; continue; }

                  p.speed = wind.speed;
                  var moveDir = (wind.direction + 180) % 360;
                  var moveRad = moveDir * Math.PI / 180;
                  var stepDeg = 0.04 + (wind.speed / 60) * 0.12;
                  var dLat = stepDeg * Math.cos(moveRad);
                  var dLng = stepDeg * Math.sin(moveRad) / Math.cos(p.lat * Math.PI / 180);

                  p.lat += dLat;
                  p.lng += dLng;
                  p.trail.push([p.lng, p.lat]);
                  var maxLen = this.trailLenForSpeed(p.speed);
                  while (p.trail.length > maxLen) p.trail.shift();
                }

                var features = [];
                for (var i = 0; i < this.particles.length; i++) {
                  var p = this.particles[i];
                  if (p.trail.length < 2) continue;
                  features.push({
                    type: 'Feature',
                    geometry: { type: 'LineString', coordinates: p.trail.slice() },
                    properties: { color: this.colorForSpeed(p.speed) }
                  });
                }

                var src = map.getSource('wind-streamlines');
                if (src) {
                  src.setData({ type: 'FeatureCollection', features: features });
                }
              },

              interpolateWind: function(lat, lng) {
                if (this.windField.length === 0) return null;
                var totalWeight = 0, weightedSpeed = 0, weightedSinDir = 0, weightedCosDir = 0;

                for (var i = 0; i < this.windField.length; i++) {
                  var pt = this.windField[i];
                  var dLat = pt.lat - lat, dLng = pt.lng - lng;
                  var dist = dLat * dLat + dLng * dLng;
                  if (dist < 0.0001) return pt;
                  var w = 1.0 / dist;
                  totalWeight += w;
                  weightedSpeed += pt.speed * w;
                  weightedSinDir += Math.sin(pt.direction * Math.PI / 180) * w;
                  weightedCosDir += Math.cos(pt.direction * Math.PI / 180) * w;
                }

                if (totalWeight === 0) return null;
                return {
                  speed: weightedSpeed / totalWeight,
                  direction: (Math.atan2(weightedSinDir / totalWeight, weightedCosDir / totalWeight) * 180 / Math.PI + 360) % 360
                };
              }
            };
            console.log('[EFB] Particle animation system initialized');
          })();
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

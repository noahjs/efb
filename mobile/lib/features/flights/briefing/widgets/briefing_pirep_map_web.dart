import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../../core/config/app_config.dart';
import '../../../../models/briefing.dart';

// Re-export helpers so pirep_detail.dart can use them on web too.
enum Severity { none, light, moderate, severe }

Severity extractSeverity(String? text) {
  if (text == null || text.isEmpty) return Severity.none;
  final upper = text.toUpperCase();
  if (upper.contains('SEV') ||
      upper.contains('EXTREME') ||
      upper.contains('EXTM')) {
    return Severity.severe;
  }
  if (upper.contains('MOD')) return Severity.moderate;
  if (upper.contains('LGT') || upper.contains('LIGHT')) return Severity.light;
  return Severity.light;
}

String severityHex(Severity severity) {
  switch (severity) {
    case Severity.none:
      return '#4CAF50';
    case Severity.light:
      return '#29B6F6';
    case Severity.moderate:
      return '#FFC107';
    case Severity.severe:
      return '#FF5252';
  }
}

String _symbolChar(Severity tbSev, Severity iceSev) {
  if (tbSev != Severity.none) {
    return tbSev == Severity.light ? '\u25BD' : '\u25BC';
  }
  if (iceSev != Severity.none) {
    return iceSev == Severity.light ? '\u25C7' : '\u25C6';
  }
  return '\u25CF';
}

String _symbolColorHex(Severity tbSev, Severity iceSev) {
  if (tbSev != Severity.none) return severityHex(tbSev);
  if (iceSev != Severity.none) return severityHex(iceSev);
  return '#4CAF50';
}

@JS('_efbBriefingPirepTap')
external set _onPirepTapJs(JSFunction? fn);

/// Web PIREP map for briefing using Mapbox GL JS.
class BriefingPirepMap extends StatefulWidget {
  final List<BriefingPirep> pireps;
  final List<BriefingWaypoint> waypoints;
  final ValueChanged<BriefingPirep> onPirepTapped;
  final VoidCallback onEmptyTapped;

  const BriefingPirepMap({
    super.key,
    required this.pireps,
    required this.waypoints,
    required this.onPirepTapped,
    required this.onEmptyTapped,
  });

  @override
  State<BriefingPirepMap> createState() => _BriefingPirepMapState();
}

class _BriefingPirepMapState extends State<BriefingPirepMap> {
  final String _viewType =
      'briefing-pirep-map-${DateTime.now().millisecondsSinceEpoch}';
  late final String _mapVar;
  final List<web.HTMLScriptElement> _injectedScripts = [];

  @override
  void initState() {
    super.initState();
    _mapVar = 'briefingPirepMap_${DateTime.now().millisecondsSinceEpoch}';

    _onPirepTapJs = ((JSString indexStr) {
      final str = indexStr.toDart;
      if (str.isEmpty) {
        widget.onEmptyTapped();
      } else {
        final idx = int.tryParse(str);
        if (idx != null && idx >= 0 && idx < widget.pireps.length) {
          widget.onPirepTapped(widget.pireps[idx]);
        }
      }
    }).toJS;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container =
          web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'briefing-pirep-map-$viewId';
      container.style
        ..width = '100%'
        ..height = '100%'
        ..position = 'relative';

      Future.delayed(const Duration(milliseconds: 100), () {
        _initMap(container.id);
      });

      return container;
    });
  }

  @override
  void dispose() {
    _onPirepTapJs = null;
    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (map) { map.remove(); }
        delete window.$_mapVar;
      })();
    ''');
    for (final script in _injectedScripts) {
      script.remove();
    }
    _injectedScripts.clear();
    super.dispose();
  }

  List<double> _computeCenter() {
    if (widget.waypoints.isEmpty) return [-98.0, 39.0];
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final wp in widget.waypoints) {
      if (wp.latitude < minLat) minLat = wp.latitude;
      if (wp.latitude > maxLat) maxLat = wp.latitude;
      if (wp.longitude < minLng) minLng = wp.longitude;
      if (wp.longitude > maxLng) maxLng = wp.longitude;
    }
    for (final p in widget.pireps) {
      if (p.latitude == null || p.longitude == null) continue;
      if (p.latitude! < minLat) minLat = p.latitude!;
      if (p.latitude! > maxLat) maxLat = p.latitude!;
      if (p.longitude! < minLng) minLng = p.longitude!;
      if (p.longitude! > maxLng) maxLng = p.longitude!;
    }
    return [(minLng + maxLng) / 2, (minLat + maxLat) / 2];
  }

  double _computeZoom() {
    if (widget.waypoints.isEmpty) return 3.5;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final wp in widget.waypoints) {
      if (wp.latitude < minLat) minLat = wp.latitude;
      if (wp.latitude > maxLat) maxLat = wp.latitude;
      if (wp.longitude < minLng) minLng = wp.longitude;
      if (wp.longitude > maxLng) maxLng = wp.longitude;
    }
    final latPad = (maxLat - minLat) * 0.15 + 0.5;
    final lngPad = (maxLng - minLng) * 0.15 + 0.5;
    final span = (maxLat - minLat + 2 * latPad) > (maxLng - minLng + 2 * lngPad)
        ? (maxLat - minLat + 2 * latPad)
        : (maxLng - minLng + 2 * lngPad);
    if (span > 40) return 3.0;
    if (span > 20) return 4.0;
    if (span > 10) return 5.0;
    if (span > 5) return 6.0;
    if (span > 2) return 7.0;
    return 8.0;
  }

  Map<String, dynamic> _buildPirepGeoJson() {
    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.pireps.length; i++) {
      final p = widget.pireps[i];
      if (p.latitude == null || p.longitude == null) continue;
      final tbSev = extractSeverity(p.turbulence);
      final iceSev = extractSeverity(p.icing);
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [p.longitude, p.latitude],
        },
        'properties': {
          'index': i,
          'symbol': _symbolChar(tbSev, iceSev),
          'color': _symbolColorHex(tbSev, iceSev),
          'isUrgent': p.urgency == 'UUA',
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Map<String, dynamic> _buildRouteGeoJson() {
    if (widget.waypoints.isEmpty) {
      return {'type': 'FeatureCollection', 'features': []};
    }
    final coords =
        widget.waypoints.map((wp) => [wp.longitude, wp.latitude]).toList();
    final features = <Map<String, dynamic>>[
      {
        'type': 'Feature',
        'geometry': {'type': 'LineString', 'coordinates': coords},
        'properties': {},
      },
      ...widget.waypoints
          .where((wp) => wp.type == 'departure' || wp.type == 'destination')
          .map((wp) => {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [wp.longitude, wp.latitude],
                },
                'properties': {'label': wp.identifier},
              }),
    ];
    return {'type': 'FeatureCollection', 'features': features};
  }

  void _initMap(String containerId) {
    final pirepStr = jsonEncode(_buildPirepGeoJson())
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'");
    final routeStr = jsonEncode(_buildRouteGeoJson())
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'");
    final center = _computeCenter();
    final zoom = _computeZoom();

    _evalJs('''
      (function() {
        if (typeof mapboxgl === 'undefined') {
          console.error('Mapbox GL JS not loaded');
          return;
        }
        mapboxgl.accessToken = '${AppConfig.mapboxToken}';

        var map = new mapboxgl.Map({
          container: '$containerId',
          style: 'mapbox://styles/mapbox/dark-v11',
          center: [${center[0]}, ${center[1]}],
          zoom: $zoom
        });

        window.$_mapVar = map;

        map.on('load', function() {
          // Route line
          var routeData = JSON.parse('$routeStr');
          map.addSource('route', { type: 'geojson', data: routeData });
          map.addLayer({
            id: 'route-line',
            type: 'line',
            source: 'route',
            paint: {
              'line-color': '#448AFF',
              'line-width': 2.5,
              'line-opacity': 0.7
            }
          });
          map.addLayer({
            id: 'route-labels',
            type: 'symbol',
            source: 'route',
            layout: {
              'text-field': ['get', 'label'],
              'text-size': 12,
              'text-offset': [0, -1.2],
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
            },
            paint: {
              'text-color': '#FFFFFF',
              'text-halo-color': '#000000',
              'text-halo-width': 1
            }
          });

          // PIREPs
          var pirepData = JSON.parse('$pirepStr');
          map.addSource('pireps', { type: 'geojson', data: pirepData });
          map.addLayer({
            id: 'pirep-symbols',
            type: 'symbol',
            source: 'pireps',
            layout: {
              'text-field': ['get', 'symbol'],
              'text-size': 16,
              'text-allow-overlap': true,
              'text-ignore-placement': true,
              'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
            },
            paint: {
              'text-color': ['get', 'color']
            }
          });
          map.addLayer({
            id: 'pirep-urgent-ring',
            type: 'circle',
            source: 'pireps',
            filter: ['==', ['get', 'isUrgent'], true],
            paint: {
              'circle-radius': 12,
              'circle-color': 'transparent',
              'circle-stroke-width': 2,
              'circle-stroke-color': '#FF5252',
              'circle-opacity': 0.7
            }
          });

          map.on('click', 'pirep-symbols', function(e) {
            if (e.features && e.features.length > 0) {
              var idx = e.features[0].properties.index;
              if (window._efbBriefingPirepTap) {
                window._efbBriefingPirepTap(String(idx));
              }
            }
          });
          map.on('click', function(e) {
            var features = map.queryRenderedFeatures(e.point, { layers: ['pirep-symbols'] });
            if (!features || features.length === 0) {
              if (window._efbBriefingPirepTap) window._efbBriefingPirepTap('');
            }
          });
          map.on('mouseenter', 'pirep-symbols', function() {
            map.getCanvas().style.cursor = 'pointer';
          });
          map.on('mouseleave', 'pirep-symbols', function() {
            map.getCanvas().style.cursor = '';
          });
        });
      })();
    ''');
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

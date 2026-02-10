import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/config/app_config.dart';
import 'advisory_map_native.dart' show enrichGeoJson;

@JS('_efbAdvisoryTap')
external set _onAdvisoryTapJs(JSFunction? fn);

/// Web advisory map using Mapbox GL JS via HtmlElementView.
class AdvisoryMap extends StatefulWidget {
  final Map<String, dynamic> geojson;
  final ValueChanged<List<Map<String, dynamic>>>? onFeaturesTapped;

  const AdvisoryMap({
    super.key,
    required this.geojson,
    this.onFeaturesTapped,
  });

  @override
  State<AdvisoryMap> createState() => _AdvisoryMapState();
}

class _AdvisoryMapState extends State<AdvisoryMap> {
  final String _viewType =
      'advisory-map-${DateTime.now().millisecondsSinceEpoch}';
  late final String _mapVar;
  final List<web.HTMLScriptElement> _injectedScripts = [];

  @override
  void initState() {
    super.initState();
    _mapVar = 'advisoryMap_${DateTime.now().millisecondsSinceEpoch}';

    _onAdvisoryTapJs = ((JSString propsJson) {
      if (propsJson.toDart.isEmpty) {
        widget.onFeaturesTapped?.call([]);
      } else {
        final decoded = jsonDecode(propsJson.toDart);
        if (decoded is List) {
          final allProps = decoded
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          widget.onFeaturesTapped?.call(allProps);
        } else if (decoded is Map) {
          widget.onFeaturesTapped
              ?.call([Map<String, dynamic>.from(decoded)]);
        }
      }
    }).toJS;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container =
          web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'advisory-map-$viewId';
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
  void didUpdateWidget(covariant AdvisoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geojson != widget.geojson) {
      _updateSourceData();
    }
  }

  void _updateSourceData() {
    final enriched = enrichGeoJson(widget.geojson);
    final geojsonStr =
        jsonEncode(enriched).replaceAll(r'\', r'\\').replaceAll("'", r"\'");

    _evalJs('''
      (function() {
        var map = window.$_mapVar;
        if (map && map.getSource('advisories')) {
          map.getSource('advisories').setData(JSON.parse('$geojsonStr'));
        }
      })();
    ''');
  }

  @override
  void dispose() {
    _onAdvisoryTapJs = null;
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

  void _initMap(String containerId) {
    final enriched = enrichGeoJson(widget.geojson);
    final geojsonStr =
        jsonEncode(enriched).replaceAll(r'\', r'\\').replaceAll("'", r"\'");

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
          center: [-98, 39],
          zoom: 3.5
        });

        window.$_mapVar = map;

        map.on('load', function() {
          var data = JSON.parse('$geojsonStr');
          map.addSource('advisories', { type: 'geojson', data: data });

          // Filled polygons
          map.addLayer({
            id: 'advisory-fill',
            type: 'fill',
            source: 'advisories',
            filter: ['==', ['geometry-type'], 'Polygon'],
            paint: {
              'fill-color': ['get', 'color'],
              'fill-opacity': 0.15
            }
          });

          // Polygon outlines
          map.addLayer({
            id: 'advisory-outline',
            type: 'line',
            source: 'advisories',
            filter: ['==', ['geometry-type'], 'Polygon'],
            paint: {
              'line-color': ['get', 'color'],
              'line-width': 2
            }
          });

          // LineString features (FZLVL contours) — dashed
          map.addLayer({
            id: 'advisory-line',
            type: 'line',
            source: 'advisories',
            filter: ['==', ['geometry-type'], 'LineString'],
            paint: {
              'line-color': ['get', 'color'],
              'line-width': 2,
              'line-dasharray': [5, 3]
            }
          });

          // Click handler — query all features at click point
          map.on('click', function(e) {
            var features = map.queryRenderedFeatures(e.point, {
              layers: ['advisory-fill', 'advisory-outline', 'advisory-line']
            });
            if (!features || features.length === 0) {
              if (window._efbAdvisoryTap) window._efbAdvisoryTap('');
              return;
            }
            // Deduplicate (fill + outline return same feature twice)
            var seen = {};
            var unique = [];
            for (var i = 0; i < features.length; i++) {
              var p = features[i].properties;
              var key = p.notamNumber ? 'tfr:' + p.notamNumber : (p.hazard || '') + '|' + (p.tag || p.seriesId || p.cwsu || '') + '|' + (p.validTime || p.validTimeFrom || '');
              if (!seen[key]) {
                seen[key] = true;
                unique.push(p);
              }
            }
            if (window._efbAdvisoryTap) window._efbAdvisoryTap(JSON.stringify(unique));
          });

          map.on('mouseenter', 'advisory-fill', function() {
            map.getCanvas().style.cursor = 'pointer';
          });
          map.on('mouseleave', 'advisory-fill', function() {
            map.getCanvas().style.cursor = '';
          });
          map.on('mouseenter', 'advisory-line', function() {
            map.getCanvas().style.cursor = 'pointer';
          });
          map.on('mouseleave', 'advisory-line', function() {
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

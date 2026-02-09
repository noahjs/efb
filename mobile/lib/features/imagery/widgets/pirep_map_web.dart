import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../maps/widgets/map_view.dart' show mapboxAccessToken;

@JS('_efbPirepTap')
external set _onPirepTapJs(JSFunction? fn);

/// Web PIREP map using Mapbox GL JS via HtmlElementView.
class PirepMap extends StatefulWidget {
  final Map<String, dynamic> geojson;
  final ValueChanged<Map<String, dynamic>>? onFeatureTapped;

  const PirepMap({
    super.key,
    required this.geojson,
    this.onFeatureTapped,
  });

  @override
  State<PirepMap> createState() => _PirepMapState();
}

class _PirepMapState extends State<PirepMap> {
  final String _viewType =
      'pirep-map-${DateTime.now().millisecondsSinceEpoch}';
  late final String _mapVar;
  final List<web.HTMLScriptElement> _injectedScripts = [];

  @override
  void initState() {
    super.initState();
    _mapVar = 'pirepMap_${DateTime.now().millisecondsSinceEpoch}';

    _onPirepTapJs = ((JSString propsJson) {
      if (propsJson.toDart.isEmpty) {
        widget.onFeatureTapped?.call({});
      } else {
        final props = Map<String, dynamic>.from(
            jsonDecode(propsJson.toDart) as Map);
        widget.onFeatureTapped?.call(props);
      }
    }).toJS;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container =
          web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'pirep-map-$viewId';
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

  String _turbulenceColorHex(String intensity) {
    switch (intensity.toUpperCase()) {
      case 'NEG':
      case 'SMTH':
      case 'SMOOTH':
        return '#4CAF50';
      case 'LGT':
      case 'LIGHT':
      case 'LGT-MOD':
        return '#29B6F6';
      case 'MOD':
      case 'MODERATE':
      case 'MOD-SEV':
        return '#FFC107';
      case 'SEV':
      case 'SEVERE':
      case 'SEV-EXTM':
      case 'EXTM':
      case 'EXTREME':
        return '#FF5252';
      default:
        return '#B0B4BC';
    }
  }

  Map<String, dynamic> _enrichGeoJson(Map<String, dynamic> original) {
    final features = (original['features'] as List<dynamic>?) ?? [];
    final enrichedFeatures = features.map((f) {
      final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
      final props =
          Map<String, dynamic>.from(feature['properties'] as Map? ?? {});

      final tbInt = (props['tbInt1'] as String? ?? '').toUpperCase();
      final airepType = props['airepType'] as String? ?? '';
      props['color'] = _turbulenceColorHex(tbInt);
      props['isUrgent'] = airepType == 'URGENT PIREP';

      feature['properties'] = props;
      return feature;
    }).toList();

    return {
      'type': 'FeatureCollection',
      'features': enrichedFeatures,
    };
  }

  void _initMap(String containerId) {
    final enriched = _enrichGeoJson(widget.geojson);
    final geojsonStr =
        jsonEncode(enriched).replaceAll(r'\', r'\\').replaceAll("'", r"\'");

    _evalJs('''
      (function() {
        if (typeof mapboxgl === 'undefined') {
          console.error('Mapbox GL JS not loaded');
          return;
        }
        mapboxgl.accessToken = '$mapboxAccessToken';

        var map = new mapboxgl.Map({
          container: '$containerId',
          style: 'mapbox://styles/mapbox/dark-v11',
          center: [-98, 39],
          zoom: 3.5
        });

        window.$_mapVar = map;

        map.on('load', function() {
          var data = JSON.parse('$geojsonStr');
          map.addSource('pireps', { type: 'geojson', data: data });

          map.addLayer({
            id: 'pirep-circles',
            type: 'circle',
            source: 'pireps',
            paint: {
              'circle-radius': 6,
              'circle-color': ['get', 'color'],
              'circle-stroke-width': 1.5,
              'circle-stroke-color': 'rgba(255,255,255,0.6)',
              'circle-opacity': 0.85
            }
          });

          map.addLayer({
            id: 'pirep-urgent-ring',
            type: 'circle',
            source: 'pireps',
            filter: ['==', ['get', 'isUrgent'], true],
            paint: {
              'circle-radius': 10,
              'circle-color': 'transparent',
              'circle-stroke-width': 2,
              'circle-stroke-color': '#FF5252',
              'circle-opacity': 0.7
            }
          });

          map.on('click', 'pirep-circles', function(e) {
            if (e.features && e.features.length > 0) {
              var props = JSON.stringify(e.features[0].properties);
              if (window._efbPirepTap) window._efbPirepTap(props);
            }
          });

          map.on('click', function(e) {
            var features = map.queryRenderedFeatures(e.point, { layers: ['pirep-circles'] });
            if (!features || features.length === 0) {
              if (window._efbPirepTap) window._efbPirepTap('');
            }
          });

          map.on('mouseenter', 'pirep-circles', function() {
            map.getCanvas().style.cursor = 'pointer';
          });
          map.on('mouseleave', 'pirep-circles', function() {
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

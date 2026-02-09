import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../maps/widgets/map_view.dart' show mapboxAccessToken;
import 'pirep_symbols.dart';

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

  Map<String, dynamic> _enrichGeoJson(Map<String, dynamic> original) {
    final features = (original['features'] as List<dynamic>?) ?? [];
    final enrichedFeatures = features.map((f) {
      final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
      final props =
          Map<String, dynamic>.from(feature['properties'] as Map? ?? {});

      final airepType = props['airepType'] as String? ?? '';
      final iconName = pirepIconName(props);
      props['symbol'] = _symbolChar(iconName);
      props['color'] = _symbolColorHex(iconName);
      props['isUrgent'] = airepType == 'URGENT PIREP';

      feature['properties'] = props;
      return feature;
    }).toList();

    return {
      'type': 'FeatureCollection',
      'features': enrichedFeatures,
    };
  }

  String _symbolChar(String iconName) {
    if (iconName.contains('turb')) {
      return iconName.endsWith('-lgt') ? '\u25BD' : '\u25BC';
    }
    if (iconName.contains('ice')) {
      return iconName.endsWith('-lgt') ? '\u25C7' : '\u25C6';
    }
    return '\u25CF';
  }

  String _symbolColorHex(String iconName) {
    if (iconName.endsWith('-lgt')) return '#29B6F6';
    if (iconName.endsWith('-mod')) return '#FFC107';
    if (iconName.endsWith('-sev')) return '#FF5252';
    if (iconName == 'pirep-neg') return '#4CAF50';
    return '#B0B4BC';
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

          // Symbol layer using Unicode text characters
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

          // Urgent ring layer
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
              var props = JSON.stringify(e.features[0].properties);
              if (window._efbPirepTap) window._efbPirepTap(props);
            }
          });

          map.on('click', function(e) {
            var features = map.queryRenderedFeatures(e.point, { layers: ['pirep-symbols'] });
            if (!features || features.length === 0) {
              if (window._efbPirepTap) window._efbPirepTap('');
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

/// Severity level extracted from turbulence/icing text.
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

/// Native (iOS/Android/macOS) PIREP map for briefing.
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
  MapboxMap? _map;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppConfig.mapboxToken);
  }

  CameraOptions _cameraForRoute() {
    if (widget.waypoints.isEmpty) {
      return CameraOptions(
        center: Point(coordinates: Position(-98.0, 39.0)),
        zoom: 3.5,
      );
    }

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

    final latPad = (maxLat - minLat) * 0.15 + 0.5;
    final lngPad = (maxLng - minLng) * 0.15 + 0.5;
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final span = latSpan > lngSpan ? latSpan : lngSpan;
    double zoom;
    if (span > 40) {
      zoom = 3.0;
    } else if (span > 20) {
      zoom = 4.0;
    } else if (span > 10) {
      zoom = 5.0;
    } else if (span > 5) {
      zoom = 6.0;
    } else if (span > 2) {
      zoom = 7.0;
    } else {
      zoom = 8.0;
    }

    return CameraOptions(
      center: Point(coordinates: Position(centerLng, centerLat)),
      zoom: zoom,
    );
  }

  void _onMapCreated(MapboxMap map) {
    _map = map;
    map.setOnMapTapListener(_onMapTap);
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    final map = _map;
    if (map == null) return;

    await _addRouteLayer(map);
    await _addPirepLayers(map);
  }

  Future<void> _addRouteLayer(MapboxMap map) async {
    if (widget.waypoints.isEmpty) return;

    final coords = widget.waypoints
        .map((wp) => [wp.longitude, wp.latitude])
        .toList();

    final routeGeoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
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
      ],
    });

    try {
      await map.style.addSource(
        GeoJsonSource(id: 'route', data: routeGeoJson),
      );
      await map.style.addLayer(LineLayer(
        id: 'route-line',
        sourceId: 'route',
        lineColor: AppColors.primary.toARGB32(),
        lineWidth: 2.5,
        lineOpacity: 0.7,
      ));
      await map.style.addLayer(SymbolLayer(
        id: 'route-labels',
        sourceId: 'route',
        textField: '{label}',
        textSize: 12.0,
        textOffset: [0.0, -1.2],
        textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      ));
      await map.style.setStyleLayerProperty(
          'route-labels', 'text-color', '#FFFFFF');
      await map.style.setStyleLayerProperty(
          'route-labels', 'text-halo-color', '#000000');
      await map.style.setStyleLayerProperty(
          'route-labels', 'text-halo-width', 1.0);
    } catch (e) {
      debugPrint('Failed to add route layer: $e');
    }
  }

  Future<void> _addPirepLayers(MapboxMap map) async {
    if (widget.pireps.isEmpty) return;

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

    final geojsonStr = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    try {
      await map.style.addSource(
        GeoJsonSource(id: 'pireps', data: geojsonStr),
      );
      await map.style.addLayer(SymbolLayer(
        id: 'pirep-symbols',
        sourceId: 'pireps',
        textField: '{symbol}',
        textSize: 16.0,
        textAllowOverlap: true,
        textIgnorePlacement: true,
        textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      ));
      await map.style.setStyleLayerProperty(
          'pirep-symbols', 'text-color', ['get', 'color']);
      await map.style.addLayer(CircleLayer(
        id: 'pirep-urgent-ring',
        sourceId: 'pireps',
        circleRadius: 12.0,
        circleColor: const Color(0x00000000).toARGB32(),
        circleStrokeWidth: 2.0,
        circleStrokeColor: AppColors.error.toARGB32(),
        circleOpacity: 0.7,
        filter: ['==', ['get', 'isUrgent'], true],
      ));
    } catch (e) {
      debugPrint('Failed to add PIREP layers: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;

    final point = context.touchPosition;
    final screenCoord = ScreenCoordinate(x: point.x, y: point.y);

    try {
      final results = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
        RenderedQueryOptions(
            layerIds: ['pirep-symbols', 'pirep-urgent-ring']),
      );

      if (results.isNotEmpty && results.first != null) {
        final props = results.first!.queriedFeature.feature['properties'];
        if (props is Map) {
          final idx = props['index'];
          if (idx is int && idx >= 0 && idx < widget.pireps.length) {
            widget.onPirepTapped(widget.pireps[idx]);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to query PIREP feature: $e');
    }

    widget.onEmptyTapped();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('briefing-pirep-map'),
      styleUri: MapboxStyles.DARK,
      cameraOptions: _cameraForRoute(),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}

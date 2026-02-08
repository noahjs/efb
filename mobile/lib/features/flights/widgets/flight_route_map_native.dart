import 'dart:math';

import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';
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
  MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    map.gestures.updateSettings(GesturesSettings(
      scrollEnabled: false,
      pinchToZoomEnabled: false,
      doubleTapToZoomInEnabled: false,
      doubleTouchToZoomOutEnabled: false,
      rotateEnabled: false,
    ));
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    final map = _mapboxMap;
    if (map == null) return;

    await _addRouteAndMarkers(map);
    await _fitCamera(map);
  }

  Future<void> _addRouteAndMarkers(MapboxMap map) async {
    final depLng = widget.depLng;
    final depLat = widget.depLat;
    final destLng = widget.destLng;
    final destLat = widget.destLat;

    // Route line
    final lineGeoJson =
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":'
        '[[$depLng,$depLat],[$destLng,$destLat]]}}';

    try {
      await map.style.addSource(
        GeoJsonSource(id: 'route-source', data: lineGeoJson),
      );
      await map.style.addLayer(LineLayer(
        id: 'route-line',
        sourceId: 'route-source',
        lineColor: AppColors.routeMagenta.toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.9,
      ));
    } catch (e) {
      debugPrint('FlightRouteMap: Failed to add route line: $e');
    }

    // Airport markers
    final features = [
      (widget.depId, depLng, depLat),
      (widget.destId, destLng, destLat),
    ]
        .map((a) =>
            '{"type":"Feature","geometry":{"type":"Point","coordinates":'
            '[${a.$2},${a.$3}]},"properties":{"id":"${a.$1}"}}')
        .join(',');

    final markersGeoJson =
        '{"type":"FeatureCollection","features":[$features]}';

    try {
      await map.style.addSource(
        GeoJsonSource(id: 'route-airports-source', data: markersGeoJson),
      );

      await map.style.addLayer(CircleLayer(
        id: 'route-airports-circles',
        sourceId: 'route-airports-source',
        circleRadius: 5.0,
        circleColor: Colors.white.toARGB32(),
        circleStrokeWidth: 1.5,
        circleStrokeColor: AppColors.routeMagenta.toARGB32(),
      ));

      await map.style.addLayer(SymbolLayer(
        id: 'route-airports-labels',
        sourceId: 'route-airports-source',
        textField: '{id}',
        textSize: 11.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, -1.5],
        textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      ));
    } catch (e) {
      debugPrint('FlightRouteMap: Failed to add airport markers: $e');
    }
  }

  Future<void> _fitCamera(MapboxMap map) async {
    try {
      final bounds = CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            min(widget.depLng, widget.destLng),
            min(widget.depLat, widget.destLat),
          ),
        ),
        northeast: Point(
          coordinates: Position(
            max(widget.depLng, widget.destLng),
            max(widget.depLat, widget.destLat),
          ),
        ),
        infiniteBounds: false,
      );

      final camera = await map.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
        null, // bearing
        null, // pitch
        null, // maxZoom
        null, // offset
      );

      await map.setCamera(camera);
    } catch (e) {
      debugPrint('FlightRouteMap: Failed to fit camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final centerLat = (widget.depLat + widget.destLat) / 2;
    final centerLng = (widget.depLng + widget.destLng) / 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: MapWidget(
          key: ValueKey('route-map-${widget.depId}-${widget.destId}'),
          styleUri: MapboxStyles.SATELLITE_STREETS,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(centerLng, centerLat)),
            zoom: 7.0,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
        ),
      ),
    );
  }
}

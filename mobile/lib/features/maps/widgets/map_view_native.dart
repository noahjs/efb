import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import 'map_view.dart' show mapboxAccessToken;

/// Native (iOS/Android) implementation using mapbox_maps_flutter SDK.
class PlatformMapView extends StatefulWidget {
  final String baseLayer;

  const PlatformMapView({super.key, required this.baseLayer});

  @override
  State<PlatformMapView> createState() => _PlatformMapViewState();
}

class _PlatformMapViewState extends State<PlatformMapView> {
  MapboxMap? _mapboxMap;

  static String _styleForLayer(String layer) {
    switch (layer) {
      case 'street':
        return MapboxStyles.MAPBOX_STREETS;
      case 'vfr':
      case 'satellite':
      default:
        return MapboxStyles.SATELLITE_STREETS;
    }
  }

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void didUpdateWidget(covariant PlatformMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseLayer != widget.baseLayer && _mapboxMap != null) {
      _switchStyle();
    }
  }

  Future<void> _switchStyle() async {
    final map = _mapboxMap!;
    final styleUri = _styleForLayer(widget.baseLayer);
    await map.loadStyleURI(styleUri);
    // Style load will trigger _onStyleLoaded which re-adds layers
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    if (_mapboxMap == null) return;
    if (widget.baseLayer == 'vfr') {
      await _addVfrTiles(_mapboxMap!);
    }
    await _addAirportMarkers(_mapboxMap!);
    await _addRouteLine(_mapboxMap!);
  }

  Future<void> _addVfrTiles(MapboxMap map) async {
    const charts = ['Denver', 'Cheyenne', 'Albuquerque', 'Salt_Lake_City'];
    try {
      for (final chart in charts) {
        await map.style.addSource(RasterSource(
          id: 'vfr-$chart',
          tiles: [
            'http://localhost:3001/api/tiles/vfr-sectional/$chart/{z}/{x}/{y}.png'
          ],
          tileSize: 256,
          minzoom: 5,
          maxzoom: 11,
          attribution: 'FAA VFR Sectional: $chart',
        ));

        await map.style.addLayer(RasterLayer(
          id: 'vfr-layer-$chart',
          sourceId: 'vfr-$chart',
          rasterOpacity: 0.85,
        ));
      }
    } catch (e) {
      debugPrint('Failed to add VFR tiles: $e');
    }
  }

  Future<void> _addAirportMarkers(MapboxMap map) async {
    final airports = [
      ('KAPA', -104.8493, 39.5701, 'vfr'),
      ('KBJC', -105.1172, 39.9088, 'vfr'),
      ('KDEN', -104.6737, 39.8561, 'mvfr'),
      ('KFNL', -105.0113, 40.4518, 'vfr'),
      ('KCFO', -104.7006, 38.8058, 'vfr'),
      ('KBDU', -105.2256, 40.0393, 'vfr'),
      ('KEIK', -105.0481, 40.0102, 'vfr'),
      ('KLMO', -105.1633, 40.1637, 'vfr'),
      ('KGXY', -104.6332, 40.4374, 'vfr'),
      ('KBKF', -104.7517, 39.7017, 'vfr'),
    ];

    final features = airports.map((a) {
      final (id, lng, lat, cat) = a;
      return '{"type":"Feature","geometry":{"type":"Point","coordinates":[$lng,$lat]},"properties":{"id":"$id","category":"$cat"}}';
    }).join(',');

    final geojson = '{"type":"FeatureCollection","features":[$features]}';

    try {
      await map.style
          .addSource(GeoJsonSource(id: 'airports-source', data: geojson));

      await map.style.addLayer(CircleLayer(
        id: 'airports-circles',
        sourceId: 'airports-source',
        circleRadius: 7.0,
        circleColor: AppColors.vfr.toARGB32(),
        circleStrokeWidth: 1.5,
        circleStrokeColor: Colors.white.withValues(alpha: 0.5).toARGB32(),
      ));

      await map.style.addLayer(SymbolLayer(
        id: 'airports-labels',
        sourceId: 'airports-source',
        textField: '{id}',
        textSize: 11.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, -1.5],
        textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
      ));
    } catch (e) {
      debugPrint('Failed to add airport markers: $e');
    }
  }

  Future<void> _addRouteLine(MapboxMap map) async {
    const routeGeoJson =
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-104.8493,39.5701],[-105.15,39.95],[-105.70,40.55]]}}';

    try {
      await map.style
          .addSource(GeoJsonSource(id: 'route-source', data: routeGeoJson));

      await map.style.addLayer(LineLayer(
        id: 'route-line',
        sourceId: 'route-source',
        lineColor: AppColors.routeMagenta.toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.9,
      ));
    } catch (e) {
      debugPrint('Failed to add route line: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('efb-mapbox'),
      styleUri: _styleForLayer(widget.baseLayer),
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(-104.8493, 39.5701)),
        zoom: 8.5,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}

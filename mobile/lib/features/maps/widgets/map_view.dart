import 'package:flutter/material.dart';
import 'map_view_native.dart' if (dart.library.html) 'map_view_web.dart'
    as platform_map;

const String mapboxAccessToken =
    'pk.eyJ1Ijoibm9haGpzIiwiYSI6ImNtbGQzbzF5dTBmMWszZnB4aDgzbDZzczUifQ.yv1FBDKs9T1RllaF7h_WxA';

/// Map bounds record used for airport fetching.
typedef MapBounds = ({
  double minLat,
  double maxLat,
  double minLng,
  double maxLng,
});

/// Controller to programmatically zoom/fly the map.
/// Platform views bind callbacks to their map instances.
class EfbMapController {
  VoidCallback? onZoomIn;
  VoidCallback? onZoomOut;
  void Function(double lat, double lng, {double? zoom})? onFlyTo;

  void zoomIn() => onZoomIn?.call();
  void zoomOut() => onZoomOut?.call();
  void flyTo(double lat, double lng, {double? zoom}) =>
      onFlyTo?.call(lat, lng, zoom: zoom);
}

class EfbMapView extends StatelessWidget {
  final String baseLayer;
  final bool showFlightCategory;
  final bool interactive;
  final ValueChanged<String>? onAirportTapped;
  final ValueChanged<MapBounds>? onBoundsChanged;
  final void Function(double lat, double lng, List<Map<String, dynamic>> aeroFeatures)? onMapLongPressed;
  final List<Map<String, dynamic>> airports;
  final EfbMapController? controller;

  /// Route line coordinates as [[lng, lat], ...].
  final List<List<double>> routeCoordinates;

  /// Aeronautical GeoJSON FeatureCollections (airspaces, airways, ARTCC).
  final Map<String, dynamic>? airspaceGeoJson;
  final Map<String, dynamic>? airwayGeoJson;
  final Map<String, dynamic>? artccGeoJson;

  /// TFR GeoJSON FeatureCollection overlay.
  final Map<String, dynamic>? tfrGeoJson;

  const EfbMapView({
    super.key,
    required this.baseLayer,
    this.showFlightCategory = false,
    this.interactive = true,
    this.onAirportTapped,
    this.onBoundsChanged,
    this.onMapLongPressed,
    this.airports = const [],
    this.routeCoordinates = const [],
    this.controller,
    this.airspaceGeoJson,
    this.airwayGeoJson,
    this.artccGeoJson,
    this.tfrGeoJson,
  });

  @override
  Widget build(BuildContext context) {
    return platform_map.PlatformMapView(
      baseLayer: baseLayer,
      showFlightCategory: showFlightCategory,
      interactive: interactive,
      onAirportTapped: onAirportTapped,
      onBoundsChanged: onBoundsChanged,
      onMapLongPressed: onMapLongPressed,
      airports: airports,
      routeCoordinates: routeCoordinates,
      controller: controller,
      airspaceGeoJson: airspaceGeoJson,
      airwayGeoJson: airwayGeoJson,
      artccGeoJson: artccGeoJson,
      tfrGeoJson: tfrGeoJson,
    );
  }
}

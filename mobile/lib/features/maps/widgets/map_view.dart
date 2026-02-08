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

/// Controller to programmatically zoom the map.
/// Platform views bind [onZoomIn] / [onZoomOut] to their map instances.
class EfbMapController {
  VoidCallback? onZoomIn;
  VoidCallback? onZoomOut;

  void zoomIn() => onZoomIn?.call();
  void zoomOut() => onZoomOut?.call();
}

class EfbMapView extends StatelessWidget {
  final String baseLayer;
  final bool showFlightCategory;
  final bool interactive;
  final ValueChanged<String>? onAirportTapped;
  final ValueChanged<MapBounds>? onBoundsChanged;
  final List<Map<String, dynamic>> airports;
  final EfbMapController? controller;

  /// Route line coordinates as [[lng, lat], ...].
  final List<List<double>> routeCoordinates;

  const EfbMapView({
    super.key,
    required this.baseLayer,
    this.showFlightCategory = false,
    this.interactive = true,
    this.onAirportTapped,
    this.onBoundsChanged,
    this.airports = const [],
    this.routeCoordinates = const [],
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return platform_map.PlatformMapView(
      baseLayer: baseLayer,
      showFlightCategory: showFlightCategory,
      interactive: interactive,
      onAirportTapped: onAirportTapped,
      onBoundsChanged: onBoundsChanged,
      airports: airports,
      routeCoordinates: routeCoordinates,
      controller: controller,
    );
  }
}

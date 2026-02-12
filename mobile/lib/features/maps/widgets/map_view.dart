import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxMap;
import 'map_view_native.dart' if (dart.library.html) 'map_view_web.dart'
    as platform_map;

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

  /// Callback when the underlying MapboxMap instance is ready.
  void Function(MapboxMap map)? onMapReady;

  /// Callback when the map style finishes loading (including reloads).
  /// Use this to re-apply custom overlays that get destroyed on style change.
  VoidCallback? onStyleReloaded;

  void zoomIn() => onZoomIn?.call();
  void zoomOut() => onZoomOut?.call();
  void flyTo(double lat, double lng, {double? zoom}) =>
      onFlyTo?.call(lat, lng, zoom: zoom);

  // Particle animation (platform-specific: native uses Dart timer, web uses JS)
  void Function(List<Map<String, dynamic>> windField,
      {required double minLat,
      required double maxLat,
      required double minLng,
      required double maxLng})? onUpdateParticleField;
  void Function()? onStartParticles;
  void Function()? onStopParticles;
  bool Function()? getParticlesRunning;

  void updateParticleField(
    List<Map<String, dynamic>> windField, {
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) =>
      onUpdateParticleField?.call(windField,
          minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  void startParticles() => onStartParticles?.call();
  void stopParticles() => onStopParticles?.call();
  bool get particlesRunning => getParticlesRunning?.call() ?? false;
}

class EfbMapView extends StatelessWidget {
  final String baseLayer;
  final bool showFlightCategory;
  final bool interactive;
  final ValueChanged<String>? onAirportTapped;
  final ValueChanged<Map<String, dynamic>>? onPirepTapped;
  final ValueChanged<MapBounds>? onBoundsChanged;
  final void Function(double lat, double lng, List<Map<String, dynamic>> aeroFeatures)? onMapLongPressed;
  final List<Map<String, dynamic>> airports;
  final EfbMapController? controller;

  /// Route line coordinates as [[lng, lat], ...].
  final List<List<double>> routeCoordinates;

  /// Aeronautical GeoJSON FeatureCollections (airspaces, airways, ARTCC, navaids, fixes).
  final Map<String, dynamic>? airspaceGeoJson;
  final Map<String, dynamic>? airwayGeoJson;
  final Map<String, dynamic>? artccGeoJson;
  final Map<String, dynamic>? navaidGeoJson;
  final Map<String, dynamic>? fixGeoJson;

  /// GeoJSON overlays keyed by source ID (e.g. 'tfrs', 'advisories', 'pireps').
  /// Each value is a GeoJSON FeatureCollection or null to clear.
  /// New overlays only need to be added here and in the layer registry
  /// in map_view_native.dart — no new named parameters required.
  final Map<String, Map<String, dynamic>?> overlays;

  const EfbMapView({
    super.key,
    required this.baseLayer,
    this.showFlightCategory = false,
    this.interactive = true,
    this.onAirportTapped,
    this.onPirepTapped,
    this.onBoundsChanged,
    this.onMapLongPressed,
    this.airports = const [],
    this.routeCoordinates = const [],
    this.controller,
    this.airspaceGeoJson,
    this.airwayGeoJson,
    this.artccGeoJson,
    this.navaidGeoJson,
    this.fixGeoJson,
    this.overlays = const {},
  });

  @override
  Widget build(BuildContext context) {
    return platform_map.PlatformMapView(
      baseLayer: baseLayer,
      showFlightCategory: showFlightCategory,
      interactive: interactive,
      onAirportTapped: onAirportTapped,
      onPirepTapped: onPirepTapped,
      onBoundsChanged: onBoundsChanged,
      onMapLongPressed: onMapLongPressed,
      airports: airports,
      routeCoordinates: routeCoordinates,
      controller: controller,
      airspaceGeoJson: airspaceGeoJson,
      airwayGeoJson: airwayGeoJson,
      artccGeoJson: artccGeoJson,
      navaidGeoJson: navaidGeoJson,
      fixGeoJson: fixGeoJson,
      overlays: overlays,
    );
  }
}

import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const heatmapSourceId = 'wind-heatmap';
const heatmapLayerId = 'wind-heatmap-layer';

/// Manages a wind speed heatmap raster overlay on the Mapbox map.
///
/// The source and layer are created once during style load (see
/// [createHeatmapLayer]) at the correct position in the layer stack.
/// This controller then swaps the ImageSource URL and toggles visibility.
class WindHeatmapController {
  MapboxMap? _map;
  bool _isActive = false;
  bool _isUpdating = false;
  String? _currentUrl;

  void attach(MapboxMap map) => _map = map;

  bool get isActive => _isActive;

  /// Create the ImageSource + RasterLayer during style load.
  /// Called from _onStyleLoaded so it occupies the correct z-position
  /// (above hillshade/aero, below wind arrow overlays).
  static Future<void> createHeatmapLayer(MapboxMap map) async {
    try {
      // Create with placeholder coordinates spanning the world.
      // Real coordinates are set when show() swaps the source.
      await map.style.addSource(ImageSource(
        id: heatmapSourceId,
        coordinates: [
          [-180.0, 85.0],
          [180.0, 85.0],
          [180.0, -85.0],
          [-180.0, -85.0],
        ],
      ));

      await map.style.addLayer(RasterLayer(
        id: heatmapLayerId,
        sourceId: heatmapSourceId,
        rasterOpacity: 0.55,
        visibility: Visibility.NONE,
      ));
      debugPrint('[EFB] Wind heatmap source+layer pre-created');
    } catch (e) {
      debugPrint('[EFB] Failed to pre-create heatmap layer: $e');
    }
  }

  /// Show or update the heatmap overlay by swapping the ImageSource.
  Future<void> show({
    required String imageUrl,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final map = _map;
    if (map == null) return;

    // Prevent concurrent calls from racing
    if (_isUpdating) return;

    // Skip if already showing this exact URL
    if (_isActive && _currentUrl == imageUrl) return;

    _isUpdating = true;

    try {
      // Remove and re-create the ImageSource with the new URL + bounds.
      // We keep the RasterLayer in place (it was created during style load
      // at the correct stack position).
      try {
        await map.style.removeStyleLayer(heatmapLayerId);
      } catch (_) {}
      try {
        await map.style.removeStyleSource(heatmapSourceId);
      } catch (_) {}

      final corners = [
        [minLng, maxLat],
        [maxLng, maxLat],
        [maxLng, minLat],
        [minLng, minLat],
      ];

      await map.style.addSource(ImageSource(
        id: heatmapSourceId,
        url: imageUrl,
        coordinates: corners,
      ));

      // Re-add the layer (visible this time). addLayer puts it at the top
      // of the stack. The wind-arrow symbol layers are also at the top and
      // were created earlier, so the heatmap sits above them briefly. This
      // is acceptable because the heatmap is semi-transparent.
      await map.style.addLayer(RasterLayer(
        id: heatmapLayerId,
        sourceId: heatmapSourceId,
        rasterOpacity: 0.55,
      ));

      _isActive = true;
      _currentUrl = imageUrl;
      debugPrint('[EFB] Wind heatmap showing: bounds=$minLat,$maxLat,$minLng,$maxLng');
    } catch (e) {
      debugPrint('[EFB] Failed to show wind heatmap: $e');
    } finally {
      _isUpdating = false;
    }
  }

  /// Remove the heatmap overlay.
  Future<void> hide() async {
    final map = _map;
    if (map == null) return;
    try {
      await map.style.setStyleLayerProperty(
        heatmapLayerId,
        'visibility',
        'none',
      );
    } catch (_) {}
    _isActive = false;
    _currentUrl = null;
  }

  /// Re-apply after a Mapbox style reload (source/layer were destroyed).
  Future<void> reapply() async {
    if (!_isActive || _currentUrl == null) return;
    _isActive = false;
    _isUpdating = false;
  }
}

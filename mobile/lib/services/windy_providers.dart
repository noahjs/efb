import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../features/maps/widgets/map_view.dart';
import '../features/maps/widgets/wind_particle_animator.dart';

class WindGridParams {
  final MapBounds bounds;
  final int altitude;

  const WindGridParams({required this.bounds, required this.altitude});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindGridParams &&
          bounds.minLat.toStringAsFixed(1) ==
              other.bounds.minLat.toStringAsFixed(1) &&
          bounds.maxLat.toStringAsFixed(1) ==
              other.bounds.maxLat.toStringAsFixed(1) &&
          bounds.minLng.toStringAsFixed(1) ==
              other.bounds.minLng.toStringAsFixed(1) &&
          bounds.maxLng.toStringAsFixed(1) ==
              other.bounds.maxLng.toStringAsFixed(1) &&
          altitude == other.altitude;

  @override
  int get hashCode =>
      bounds.minLat.toStringAsFixed(1).hashCode ^
      bounds.maxLat.toStringAsFixed(1).hashCode ^
      bounds.minLng.toStringAsFixed(1).hashCode ^
      bounds.maxLng.toStringAsFixed(1).hashCode ^
      altitude.hashCode;
}

final windGridProvider =
    FutureProvider.family<Map<String, dynamic>?, WindGridParams>(
        (ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  return apiClient.getWindGrid(
    minLat: params.bounds.minLat,
    maxLat: params.bounds.maxLat,
    minLng: params.bounds.minLng,
    maxLng: params.bounds.maxLng,
    altitude: params.altitude,
  );
});

final windStreamlineProvider =
    FutureProvider.family<Map<String, dynamic>?, WindGridParams>(
        (ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  return apiClient.getWindStreamlines(
    minLat: params.bounds.minLat,
    maxLat: params.bounds.maxLat,
    minLng: params.bounds.minLng,
    maxLng: params.bounds.maxLng,
    altitude: params.altitude,
  );
});

/// Extracts wind field points from the wind grid GeoJSON for particle animation.
/// Uses the existing windGridProvider data (0.5° spacing requested).
final windFieldProvider =
    FutureProvider.family<List<WindFieldPoint>, WindGridParams>(
        (ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.getWindGrid(
    minLat: params.bounds.minLat,
    maxLat: params.bounds.maxLat,
    minLng: params.bounds.minLng,
    maxLng: params.bounds.maxLng,
    altitude: params.altitude,
    spacing: 0.5,
  );

  if (data == null) return [];

  final features = data['features'] as List<dynamic>? ?? [];
  return features.map((f) {
    final coords = f['geometry']['coordinates'] as List<dynamic>;
    final props = f['properties'] as Map<String, dynamic>;
    return WindFieldPoint(
      lat: (coords[1] as num).toDouble(),
      lng: (coords[0] as num).toDouble(),
      direction: (props['direction'] as num).toDouble(),
      speed: (props['speed'] as num).toDouble(),
    );
  }).toList();
});

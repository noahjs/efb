import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../features/maps/widgets/map_view.dart';

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

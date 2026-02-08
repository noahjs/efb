import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Provider for airspace polygons in map bounds (Class B/C/D/E)
final mapAirspacesProvider = FutureProvider.family<Map<String, dynamic>,
    ({double minLat, double maxLat, double minLng, double maxLng})>(
  (ref, bounds) async {
    final client = ref.read(apiClientProvider);
    return client.getAirspacesInBounds(
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: bounds.minLng,
      maxLng: bounds.maxLng,
    );
  },
);

/// Provider for airway line segments in map bounds
final mapAirwaysProvider = FutureProvider.family<Map<String, dynamic>,
    ({double minLat, double maxLat, double minLng, double maxLng})>(
  (ref, bounds) async {
    final client = ref.read(apiClientProvider);
    return client.getAirwaysInBounds(
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: bounds.minLng,
      maxLng: bounds.maxLng,
    );
  },
);

/// Provider for ARTCC boundary polygons in map bounds
final mapArtccProvider = FutureProvider.family<Map<String, dynamic>,
    ({double minLat, double maxLat, double minLng, double maxLng})>(
  (ref, bounds) async {
    final client = ref.read(apiClientProvider);
    return client.getArtccInBounds(
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: bounds.minLng,
      maxLng: bounds.maxLng,
    );
  },
);

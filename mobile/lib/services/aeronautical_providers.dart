import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Provider for airspace polygons in map bounds (Class B/C/D/E).
/// [classes] is a comma-separated string of airspace classes to include (e.g. 'B,C,D').
/// When null, all classes are returned.
final mapAirspacesProvider = FutureProvider.family<
    Map<String, dynamic>,
    ({
      double minLat,
      double maxLat,
      double minLng,
      double maxLng,
      String? classes,
    })>(
  (ref, params) async {
    final client = ref.read(apiClientProvider);
    return client.getAirspacesInBounds(
      minLat: params.minLat,
      maxLat: params.maxLat,
      minLng: params.minLng,
      maxLng: params.maxLng,
      classes: params.classes?.split(','),
    );
  },
);

/// Provider for airway line segments in map bounds.
/// [types] is a comma-separated string of airway types to include (e.g. 'V,T').
/// When null, all types are returned.
final mapAirwaysProvider = FutureProvider.family<
    Map<String, dynamic>,
    ({
      double minLat,
      double maxLat,
      double minLng,
      double maxLng,
      String? types,
    })>(
  (ref, params) async {
    final client = ref.read(apiClientProvider);
    return client.getAirwaysInBounds(
      minLat: params.minLat,
      maxLat: params.maxLat,
      minLng: params.minLng,
      maxLng: params.maxLng,
      types: params.types?.split(','),
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

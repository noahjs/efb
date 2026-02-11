import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../models/fbo.dart';

/// Provider for starred airports (full airport objects)
final starredAirportsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(apiClientProvider);
  return client.getStarredAirports();
});

/// Provider for starred airport identifiers (for quick lookup)
final starredAirportIdsProvider = Provider<AsyncValue<Set<String>>>((ref) {
  final starred = ref.watch(starredAirportsProvider);
  return starred.whenData(
    (airports) => airports
        .map((a) => (a['identifier'] ?? '') as String)
        .where((id) => id.isNotEmpty)
        .toSet(),
  );
});

/// Provider for airport search results
final airportSearchProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, query) async {
  final client = ref.read(apiClientProvider);
  return client.searchAirports(query: query.isEmpty ? null : query);
});

/// Provider for airport detail
final airportDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final client = ref.read(apiClientProvider);
  return client.getAirport(id);
});

/// Provider for airport runways
final airportRunwaysProvider =
    FutureProvider.family<List<dynamic>, String>((ref, id) async {
  final client = ref.read(apiClientProvider);
  return client.getRunways(id);
});

/// Provider for airport frequencies
final airportFrequenciesProvider =
    FutureProvider.family<List<dynamic>, String>((ref, id) async {
  final client = ref.read(apiClientProvider);
  return client.getFrequencies(id);
});

/// Provider for METAR data (with nearest-station fallback and AWOS info)
final metarProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getNearestMetar(icao);
});

/// Provider for TAF data (nearest TAF with station attribution)
final tafProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getNearestTaf(icao);
});

/// Provider for winds aloft data
final windsAloftProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getWindsAloft(icao);
});

/// Provider for Windy-powered winds aloft (point forecast by lat/lng)
final windyWindsAloftProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, airportId) async {
  final client = ref.read(apiClientProvider);
  final airport = await ref.read(airportDetailProvider(airportId).future);
  if (airport == null) return null;
  final lat = airport['latitude'] as double?;
  final lng = airport['longitude'] as double?;
  if (lat == null || lng == null) return null;
  return client.getWindyPoint(lat: lat, lng: lng);
});

/// Provider for NOTAMs
final notamsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getNotams(icao);
});

/// Provider for D-ATIS data
final datisProvider =
    FutureProvider.family<List<dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getDatis(icao);
});

/// Provider for 7-day forecast data
final forecastProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getForecast(icao);
});

/// Provider for nearby airports
final nearbyAirportsProvider = FutureProvider.family<List<dynamic>,
    ({double lat, double lng})>(
  (ref, params) async {
    final client = ref.read(apiClientProvider);
    return client.getNearbyAirports(lat: params.lat, lng: params.lng, limit: 8);
  },
);

/// Provider for airports in map bounds
final mapAirportsProvider = FutureProvider.family<List<dynamic>,
    ({double minLat, double maxLat, double minLng, double maxLng})>(
  (ref, bounds) async {
    final client = ref.read(apiClientProvider);
    return client.getAirportsInBounds(
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: bounds.minLng,
      maxLng: bounds.maxLng,
    );
  },
);

/// Provider for navaid detail
final navaidDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final client = ref.read(apiClientProvider);
  return client.getNavaid(id);
});

/// Resolve a list of waypoint identifiers (airports, navaids, fixes)
/// to coordinates. The parameter is a comma-joined string of identifiers.
final resolvedRouteProvider =
    FutureProvider.family<List<dynamic>, String>((ref, ids) async {
  if (ids.isEmpty) return [];
  final client = ref.read(apiClientProvider);
  return client.resolveWaypoints(ids.split(','));
});

/// Provider for bulk METARs in map bounds (flight categories)
final mapMetarsProvider = FutureProvider.family<List<dynamic>,
    ({double minLat, double maxLat, double minLng, double maxLng})>(
  (ref, bounds) async {
    final client = ref.read(apiClientProvider);
    return client.getBulkMetars(
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: bounds.minLng,
      maxLng: bounds.maxLng,
    );
  },
);

/// Provider for weather stations in map bounds
final wxStationsBoundsProvider = FutureProvider.family<List<dynamic>,
    ({double minLat, double maxLat, double minLng, double maxLng})>(
  (ref, bounds) async {
    final client = ref.read(apiClientProvider);
    return client.getWxStationsInBounds(
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: bounds.minLng,
      maxLng: bounds.maxLng,
    );
  },
);

/// Provider for weather station detail
final wxStationDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final client = ref.read(apiClientProvider);
  return client.getWxStation(id);
});

/// Provider for airport FBOs
final airportFbosProvider =
    FutureProvider.family<List<Fbo>, String>((ref, id) async {
  final client = ref.read(apiClientProvider);
  final data = await client.getFbos(id);
  return data.map((j) => Fbo.fromJson(j as Map<String, dynamic>)).toList();
});

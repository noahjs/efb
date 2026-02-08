import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

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

/// Provider for METAR data
final metarProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getMetar(icao);
});

/// Provider for TAF data
final tafProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getTaf(icao);
});

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

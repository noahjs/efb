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

/// Provider for NOTAMs
final notamsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getNotams(icao);
});

/// Provider for 7-day forecast data
final forecastProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, icao) async {
  final client = ref.read(apiClientProvider);
  return client.getForecast(icao);
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

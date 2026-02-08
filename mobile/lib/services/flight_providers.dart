import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight.dart';
import 'api_client.dart';

/// Provider for the flights list, parameterized by search query
final flightsListProvider =
    FutureProvider.family<List<Flight>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.getFlights(query: query.isEmpty ? null : query);
  final items = result['items'] as List<dynamic>;
  return items.map((json) => Flight.fromJson(json)).toList();
});

/// Provider for a single flight by ID
final flightDetailProvider =
    FutureProvider.family<Flight?, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getFlight(id);
  return Flight.fromJson(json);
});

/// Service class for flight mutations — not a provider itself,
/// but accessed via flightServiceProvider for API access.
class FlightService {
  final ApiClient _api;

  FlightService(this._api);

  Future<Flight> createFlight(Map<String, dynamic> data) async {
    final json = await _api.createFlight(data);
    return Flight.fromJson(json);
  }

  Future<Flight> updateFlight(int id, Map<String, dynamic> data) async {
    final json = await _api.updateFlight(id, data);
    return Flight.fromJson(json);
  }

  Future<void> deleteFlight(int id) async {
    await _api.deleteFlight(id);
  }

  Future<Flight> copyFlight(int id) async {
    final json = await _api.copyFlight(id);
    return Flight.fromJson(json);
  }
}

final flightServiceProvider = Provider<FlightService>((ref) {
  return FlightService(ref.watch(apiClientProvider));
});

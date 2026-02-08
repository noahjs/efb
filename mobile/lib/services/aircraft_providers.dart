import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/aircraft.dart';
import 'api_client.dart';

/// Provider for the aircraft list, parameterized by search query
final aircraftListProvider =
    FutureProvider.family<List<Aircraft>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final result =
      await api.getAircraftList(query: query.isEmpty ? null : query);
  final items = result['items'] as List<dynamic>;
  return items.map((json) => Aircraft.fromJson(json)).toList();
});

/// Provider for a single aircraft by ID (with all relations)
final aircraftDetailProvider =
    FutureProvider.family<Aircraft?, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getAircraft(id);
  return Aircraft.fromJson(json);
});

/// Provider for the default aircraft
final defaultAircraftProvider = FutureProvider<Aircraft?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getDefaultAircraft();
  if (json == null) return null;
  return Aircraft.fromJson(json);
});

/// Service class for aircraft mutations
class AircraftService {
  final ApiClient _api;

  AircraftService(this._api);

  Future<Aircraft> createAircraft(Map<String, dynamic> data) async {
    final json = await _api.createAircraft(data);
    return Aircraft.fromJson(json);
  }

  Future<Aircraft> updateAircraft(int id, Map<String, dynamic> data) async {
    final json = await _api.updateAircraft(id, data);
    return Aircraft.fromJson(json);
  }

  Future<void> deleteAircraft(int id) async {
    await _api.deleteAircraft(id);
  }

  Future<Aircraft> setDefault(int id) async {
    final json = await _api.setDefaultAircraft(id);
    return Aircraft.fromJson(json);
  }

  // Profiles

  Future<PerformanceProfile> createProfile(
      int aircraftId, Map<String, dynamic> data) async {
    final json = await _api.createProfile(aircraftId, data);
    return PerformanceProfile.fromJson(json);
  }

  Future<PerformanceProfile> updateProfile(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final json = await _api.updateProfile(aircraftId, profileId, data);
    return PerformanceProfile.fromJson(json);
  }

  Future<void> deleteProfile(int aircraftId, int profileId) async {
    await _api.deleteProfile(aircraftId, profileId);
  }

  Future<PerformanceProfile> setDefaultProfile(
      int aircraftId, int profileId) async {
    final json = await _api.setDefaultProfile(aircraftId, profileId);
    return PerformanceProfile.fromJson(json);
  }

  // Fuel Tanks

  Future<FuelTank> createFuelTank(
      int aircraftId, Map<String, dynamic> data) async {
    final json = await _api.createFuelTank(aircraftId, data);
    return FuelTank.fromJson(json);
  }

  Future<FuelTank> updateFuelTank(
      int aircraftId, int tankId, Map<String, dynamic> data) async {
    final json = await _api.updateFuelTank(aircraftId, tankId, data);
    return FuelTank.fromJson(json);
  }

  Future<void> deleteFuelTank(int aircraftId, int tankId) async {
    await _api.deleteFuelTank(aircraftId, tankId);
  }

  // Equipment

  Future<AircraftEquipment> upsertEquipment(
      int aircraftId, Map<String, dynamic> data) async {
    final json = await _api.upsertEquipment(aircraftId, data);
    return AircraftEquipment.fromJson(json);
  }
}

final aircraftServiceProvider = Provider<AircraftService>((ref) {
  return AircraftService(ref.watch(apiClientProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weight_balance.dart';
import 'api_client.dart';

/// Provider for W&B profiles list, parameterized by aircraft ID
final wbProfilesProvider =
    FutureProvider.family<List<WBProfile>, int>((ref, aircraftId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.getWBProfiles(aircraftId);
  return result.map((json) => WBProfile.fromJson(json)).toList();
});

/// Provider for a single W&B profile with stations and envelopes
final wbProfileProvider = FutureProvider.family<WBProfile,
    ({int aircraftId, int profileId})>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  final json =
      await api.getWBProfile(params.aircraftId, params.profileId);
  return WBProfile.fromJson(json);
});

/// Provider for scenarios of a profile
final wbScenariosProvider = FutureProvider.family<List<WBScenario>,
    ({int aircraftId, int profileId})>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  final result =
      await api.getWBScenarios(params.aircraftId, params.profileId);
  return result
      .map((json) => WBScenario.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Provider for a flight's W&B scenario + its profile (auto-creates if needed)
final flightWBProvider = FutureProvider.family<
    ({WBScenario scenario, WBProfile profile}), int>((ref, flightId) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getFlightWBScenario(flightId);
  return (
    scenario: WBScenario.fromJson(json['scenario'] as Map<String, dynamic>),
    profile: WBProfile.fromJson(json['profile'] as Map<String, dynamic>),
  );
});

/// Service class for W&B mutations
class WBService {
  final ApiClient _api;

  WBService(this._api);

  // Profiles

  Future<WBProfile> createProfile(
      int aircraftId, Map<String, dynamic> data) async {
    final json = await _api.createWBProfile(aircraftId, data);
    return WBProfile.fromJson(json);
  }

  Future<WBProfile> updateProfile(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final json = await _api.updateWBProfile(aircraftId, profileId, data);
    return WBProfile.fromJson(json);
  }

  Future<void> deleteProfile(int aircraftId, int profileId) async {
    await _api.deleteWBProfile(aircraftId, profileId);
  }

  // Stations

  Future<WBStation> createStation(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final json = await _api.createWBStation(aircraftId, profileId, data);
    return WBStation.fromJson(json);
  }

  Future<WBStation> updateStation(int aircraftId, int profileId,
      int stationId, Map<String, dynamic> data) async {
    final json = await _api.updateWBStation(
        aircraftId, profileId, stationId, data);
    return WBStation.fromJson(json);
  }

  Future<void> deleteStation(
      int aircraftId, int profileId, int stationId) async {
    await _api.deleteWBStation(aircraftId, profileId, stationId);
  }

  // Envelopes

  Future<WBEnvelope> upsertEnvelope(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final json = await _api.upsertWBEnvelope(aircraftId, profileId, data);
    return WBEnvelope.fromJson(json);
  }

  // Scenarios

  Future<WBScenario> createScenario(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final json =
        await _api.createWBScenario(aircraftId, profileId, data);
    return WBScenario.fromJson(json);
  }

  Future<WBScenario> updateScenario(int aircraftId, int profileId,
      int scenarioId, Map<String, dynamic> data) async {
    final json = await _api.updateWBScenario(
        aircraftId, profileId, scenarioId, data);
    return WBScenario.fromJson(json);
  }

  Future<void> deleteScenario(
      int aircraftId, int profileId, int scenarioId) async {
    await _api.deleteWBScenario(aircraftId, profileId, scenarioId);
  }

  // Calculate

  Future<WBCalculationResult> calculate(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final json = await _api.calculateWB(aircraftId, profileId, data);
    return WBCalculationResult.fromJson(json);
  }
}

final wbServiceProvider = Provider<WBService>((ref) {
  return WBService(ref.watch(apiClientProvider));
});

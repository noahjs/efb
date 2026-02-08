import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';

/// Base API client for the NestJS backend
class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? '${AppConfig.apiBaseUrl}/api',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  // --- Airports ---

  Future<Map<String, dynamic>> searchAirports({
    String? query,
    String? state,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get('/airports', queryParameters: {
      if (query != null) 'q': query,
      if (state != null) 'state': state,
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  Future<Map<String, dynamic>?> getAirport(String identifier) async {
    try {
      final response = await _dio.get('/airports/$identifier');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<dynamic>> getNearbyAirports({
    required double lat,
    required double lng,
    double radiusNm = 30,
    int limit = 20,
  }) async {
    final response = await _dio.get('/airports/nearby', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius': radiusNm,
      'limit': limit,
    });
    return response.data;
  }

  Future<List<dynamic>> getAirportsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 200,
  }) async {
    final response = await _dio.get('/airports/bounds', queryParameters: {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
      'limit': limit,
    });
    return response.data;
  }

  Future<List<dynamic>> getRunways(String identifier) async {
    final response = await _dio.get('/airports/$identifier/runways');
    return response.data;
  }

  Future<List<dynamic>> getFrequencies(String identifier) async {
    final response = await _dio.get('/airports/$identifier/frequencies');
    return response.data;
  }

  // --- Weather ---

  Future<Map<String, dynamic>?> getMetar(String icao) async {
    try {
      final response = await _dio.get('/weather/metar/$icao');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTaf(String icao) async {
    try {
      final response = await _dio.get('/weather/taf/$icao');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getNearestTaf(String icao) async {
    try {
      final response = await _dio.get('/weather/taf/$icao/nearest');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getForecast(String icao) async {
    try {
      final response = await _dio.get('/weather/forecast/$icao');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWindsAloft(String icao) async {
    try {
      final response = await _dio.get('/weather/winds/$icao');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getNotams(String icao) async {
    try {
      final response = await _dio.get('/weather/notams/$icao');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getBulkMetars({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      final response = await _dio.get('/weather/stations', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      });
      return response.data;
    } catch (_) {
      return [];
    }
  }
  // --- Procedures ---

  Future<Map<String, dynamic>> getProcedures(String airportId) async {
    final response = await _dio.get('/procedures/$airportId');
    return response.data;
  }

  String getProcedurePdfUrl(String airportId, int procedureId) {
    return '${_dio.options.baseUrl}/procedures/$airportId/pdf/$procedureId';
  }

  // --- Users / Starred Airports ---

  Future<List<dynamic>> getStarredAirports() async {
    final response = await _dio.get('/users/me/starred-airports');
    return response.data;
  }

  Future<Map<String, dynamic>> starAirport(String identifier) async {
    final response =
        await _dio.put('/users/me/starred-airports/$identifier');
    return response.data;
  }

  Future<void> unstarAirport(String identifier) async {
    await _dio.delete('/users/me/starred-airports/$identifier');
  }

  // --- Flights ---

  Future<Map<String, dynamic>> getFlights({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get('/flights', queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getFlight(int id) async {
    final response = await _dio.get('/flights/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createFlight(Map<String, dynamic> data) async {
    final response = await _dio.post('/flights', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateFlight(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/flights/$id', data: data);
    return response.data;
  }

  Future<void> deleteFlight(int id) async {
    await _dio.delete('/flights/$id');
  }

  Future<Map<String, dynamic>> getFlightCalculationDebug(int id) async {
    final response = await _dio.get('/flights/$id/calculate-debug');
    return response.data;
  }

  Future<Map<String, dynamic>> copyFlight(int id) async {
    final response = await _dio.post('/flights/$id/copy');
    return response.data;
  }

  // --- Calculate ---

  Future<Map<String, dynamic>> calculateFlight({
    String? departureIdentifier,
    String? destinationIdentifier,
    String? routeString,
    int? cruiseAltitude,
    int? trueAirspeed,
    double? fuelBurnRate,
    String? etd,
    int? performanceProfileId,
  }) async {
    final response = await _dio.post('/calculate', data: {
      if (departureIdentifier != null)
        'departure_identifier': departureIdentifier,
      if (destinationIdentifier != null)
        'destination_identifier': destinationIdentifier,
      if (routeString != null) 'route_string': routeString,
      if (cruiseAltitude != null) 'cruise_altitude': cruiseAltitude,
      if (trueAirspeed != null) 'true_airspeed': trueAirspeed,
      if (fuelBurnRate != null) 'fuel_burn_rate': fuelBurnRate,
      if (etd != null) 'etd': etd,
      if (performanceProfileId != null)
        'performance_profile_id': performanceProfileId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> calculateAltitudes({
    String? departureIdentifier,
    String? destinationIdentifier,
    String? routeString,
    int? trueAirspeed,
    double? fuelBurnRate,
    int? performanceProfileId,
    required List<int> altitudes,
  }) async {
    final response = await _dio.post('/calculate/altitudes', data: {
      if (departureIdentifier != null)
        'departure_identifier': departureIdentifier,
      if (destinationIdentifier != null)
        'destination_identifier': destinationIdentifier,
      if (routeString != null) 'route_string': routeString,
      if (trueAirspeed != null) 'true_airspeed': trueAirspeed,
      if (fuelBurnRate != null) 'fuel_burn_rate': fuelBurnRate,
      if (performanceProfileId != null)
        'performance_profile_id': performanceProfileId,
      'altitudes': altitudes,
    });
    return response.data;
  }

  // --- Aircraft ---

  Future<Map<String, dynamic>> getAircraftList({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get('/aircraft', queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getAircraft(int id) async {
    final response = await _dio.get('/aircraft/$id');
    return response.data;
  }

  Future<Map<String, dynamic>?> getDefaultAircraft() async {
    try {
      final response = await _dio.get('/aircraft/default');
      if (response.data == null || response.data == '') return null;
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createAircraft(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/aircraft', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateAircraft(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/aircraft/$id', data: data);
    return response.data;
  }

  Future<void> deleteAircraft(int id) async {
    await _dio.delete('/aircraft/$id');
  }

  Future<Map<String, dynamic>> setDefaultAircraft(int id) async {
    final response = await _dio.put('/aircraft/$id/default');
    return response.data;
  }

  // --- Aircraft Performance Profiles ---

  Future<List<dynamic>> getProfiles(int aircraftId) async {
    final response = await _dio.get('/aircraft/$aircraftId/profiles');
    return response.data;
  }

  Future<Map<String, dynamic>> createProfile(
      int aircraftId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/aircraft/$aircraftId/profiles', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateProfile(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final response =
        await _dio.put('/aircraft/$aircraftId/profiles/$profileId', data: data);
    return response.data;
  }

  Future<void> deleteProfile(int aircraftId, int profileId) async {
    await _dio.delete('/aircraft/$aircraftId/profiles/$profileId');
  }

  Future<Map<String, dynamic>> setDefaultProfile(
      int aircraftId, int profileId) async {
    final response =
        await _dio.put('/aircraft/$aircraftId/profiles/$profileId/default');
    return response.data;
  }

  // --- Aircraft Fuel Tanks ---

  Future<List<dynamic>> getFuelTanks(int aircraftId) async {
    final response = await _dio.get('/aircraft/$aircraftId/fuel-tanks');
    return response.data;
  }

  Future<Map<String, dynamic>> createFuelTank(
      int aircraftId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/aircraft/$aircraftId/fuel-tanks', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateFuelTank(
      int aircraftId, int tankId, Map<String, dynamic> data) async {
    final response = await _dio
        .put('/aircraft/$aircraftId/fuel-tanks/$tankId', data: data);
    return response.data;
  }

  Future<void> deleteFuelTank(int aircraftId, int tankId) async {
    await _dio.delete('/aircraft/$aircraftId/fuel-tanks/$tankId');
  }

  // --- Aeronautical (Airspaces, Airways, ARTCC) ---

  Future<Map<String, dynamic>> getAirspacesInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    List<String>? classes,
  }) async {
    try {
      final response =
          await _dio.get('/airspaces/bounds', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
        if (classes != null) 'classes': classes.join(','),
      });
      return response.data;
    } catch (_) {
      return {'type': 'FeatureCollection', 'features': []};
    }
  }

  Future<Map<String, dynamic>> getAirwaysInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    List<String>? types,
  }) async {
    try {
      final response = await _dio.get('/airways/bounds', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
        if (types != null) 'types': types.join(','),
      });
      return response.data;
    } catch (_) {
      return {'type': 'FeatureCollection', 'features': []};
    }
  }

  Future<Map<String, dynamic>> getArtccInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      final response = await _dio.get('/artcc/bounds', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      });
      return response.data;
    } catch (_) {
      return {'type': 'FeatureCollection', 'features': []};
    }
  }

  // --- Waypoint Resolution ---

  Future<List<dynamic>> resolveWaypoints(List<String> identifiers) async {
    try {
      final response = await _dio.get('/waypoints/resolve', queryParameters: {
        'ids': identifiers.join(','),
      });
      return response.data;
    } catch (_) {
      return [];
    }
  }

  // --- Preferred Routes ---

  Future<List<dynamic>> getPreferredRoutes({
    required String origin,
    required String destination,
    String? type,
  }) async {
    final response = await _dio.get('/routes/preferred', queryParameters: {
      'origin': origin,
      'destination': destination,
      if (type != null) 'type': type,
    });
    return response.data;
  }

  Future<List<dynamic>> getPreferredRoutesFrom(String origin,
      {String? type}) async {
    final response =
        await _dio.get('/routes/preferred/from/$origin', queryParameters: {
      if (type != null) 'type': type,
    });
    return response.data;
  }

  // --- Aircraft Equipment ---

  Future<Map<String, dynamic>?> getEquipment(int aircraftId) async {
    try {
      final response = await _dio.get('/aircraft/$aircraftId/equipment');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> upsertEquipment(
      int aircraftId, Map<String, dynamic> data) async {
    final response =
        await _dio.put('/aircraft/$aircraftId/equipment', data: data);
    return response.data;
  }
}

/// Riverpod provider for the API client
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

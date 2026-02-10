import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import 'auth_interceptor.dart';

/// Base API client for the NestJS backend
class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl, Ref? ref})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? '${AppConfig.apiBaseUrl}/api',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    if (ref != null) {
      _dio.interceptors.add(AuthInterceptor(ref));
    }
  }

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

  Future<Map<String, dynamic>?> getNearestMetar(String icao) async {
    try {
      final response = await _dio.get('/weather/metar/$icao/nearest');
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
  // --- Windy (Winds Aloft) ---

  Future<Map<String, dynamic>?> getWindGrid({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int altitude,
    double? spacing,
  }) async {
    try {
      final response = await _dio.get('/windy/grid', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
        'altitude': altitude,
        if (spacing != null) 'spacing': spacing,
      });
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWindStreamlines({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int altitude,
  }) async {
    try {
      final response = await _dio.get(
        '/windy/streamlines',
        queryParameters: {
          'minLat': minLat,
          'maxLat': maxLat,
          'minLng': minLng,
          'maxLng': maxLng,
          'altitude': altitude,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWindyPoint({
    required double lat,
    required double lng,
    String? model,
  }) async {
    try {
      final response = await _dio.get('/windy/point', queryParameters: {
        'lat': lat,
        'lng': lng,
        if (model != null) 'model': model,
      });
      return response.data;
    } catch (_) {
      return null;
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

  Future<Map<String, dynamic>?> getGeoref(
      String airportId, int procedureId) async {
    try {
      final response =
          await _dio.get('/procedures/$airportId/georef/$procedureId');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  String getProcedureImageUrl(String airportId, int procedureId) {
    return '${_dio.options.baseUrl}/procedures/$airportId/image/$procedureId';
  }

  // --- Users / Profile ---

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/users/me');
    return response.data;
  }

  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> data) async {
    final response = await _dio.put('/users/me', data: data);
    return response.data;
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

  // --- Navaids & Fixes ---

  Future<List<dynamic>> searchNavaids({
    String? query,
    String? type,
    int limit = 50,
  }) async {
    final response = await _dio.get('/navaids/search', queryParameters: {
      if (query != null) 'q': query,
      if (type != null) 'type': type,
      'limit': limit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>?> getNavaid(String identifier) async {
    try {
      final response = await _dio.get('/navaids/$identifier');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<dynamic>> searchFixes({
    String? query,
    int limit = 50,
  }) async {
    final response = await _dio.get('/fixes/search', queryParameters: {
      if (query != null) 'q': query,
      'limit': limit,
    });
    return response.data;
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

  // --- Flight W&B ---

  Future<Map<String, dynamic>> getFlightWBScenario(int flightId) async {
    final response = await _dio.get('/flights/$flightId/wb-scenario');
    return response.data;
  }

  // --- Weight & Balance ---

  Future<List<dynamic>> getWBProfiles(int aircraftId) async {
    final response = await _dio.get('/aircraft/$aircraftId/wb/profiles');
    return response.data;
  }

  Future<Map<String, dynamic>> getWBProfile(
      int aircraftId, int profileId) async {
    final response =
        await _dio.get('/aircraft/$aircraftId/wb/profiles/$profileId');
    return response.data;
  }

  Future<Map<String, dynamic>> createWBProfile(
      int aircraftId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/aircraft/$aircraftId/wb/profiles', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateWBProfile(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final response = await _dio
        .put('/aircraft/$aircraftId/wb/profiles/$profileId', data: data);
    return response.data;
  }

  Future<void> deleteWBProfile(int aircraftId, int profileId) async {
    await _dio.delete('/aircraft/$aircraftId/wb/profiles/$profileId');
  }

  Future<Map<String, dynamic>> createWBStation(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final response = await _dio.post(
        '/aircraft/$aircraftId/wb/profiles/$profileId/stations',
        data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateWBStation(int aircraftId, int profileId,
      int stationId, Map<String, dynamic> data) async {
    final response = await _dio.put(
        '/aircraft/$aircraftId/wb/profiles/$profileId/stations/$stationId',
        data: data);
    return response.data;
  }

  Future<void> deleteWBStation(
      int aircraftId, int profileId, int stationId) async {
    await _dio.delete(
        '/aircraft/$aircraftId/wb/profiles/$profileId/stations/$stationId');
  }

  Future<List<dynamic>> reorderWBStations(
      int aircraftId, int profileId, List<int> stationIds) async {
    final response = await _dio.put(
        '/aircraft/$aircraftId/wb/profiles/$profileId/stations/reorder',
        data: {'station_ids': stationIds});
    return response.data;
  }

  Future<Map<String, dynamic>> upsertWBEnvelope(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final response = await _dio.put(
        '/aircraft/$aircraftId/wb/profiles/$profileId/envelopes',
        data: data);
    return response.data;
  }

  Future<List<dynamic>> getWBScenarios(
      int aircraftId, int profileId) async {
    final response = await _dio
        .get('/aircraft/$aircraftId/wb/profiles/$profileId/scenarios');
    return response.data;
  }

  Future<Map<String, dynamic>> getWBScenario(
      int aircraftId, int profileId, int scenarioId) async {
    final response = await _dio.get(
        '/aircraft/$aircraftId/wb/profiles/$profileId/scenarios/$scenarioId');
    return response.data;
  }

  Future<Map<String, dynamic>> createWBScenario(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final response = await _dio.post(
        '/aircraft/$aircraftId/wb/profiles/$profileId/scenarios',
        data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateWBScenario(int aircraftId, int profileId,
      int scenarioId, Map<String, dynamic> data) async {
    final response = await _dio.put(
        '/aircraft/$aircraftId/wb/profiles/$profileId/scenarios/$scenarioId',
        data: data);
    return response.data;
  }

  Future<void> deleteWBScenario(
      int aircraftId, int profileId, int scenarioId) async {
    await _dio.delete(
        '/aircraft/$aircraftId/wb/profiles/$profileId/scenarios/$scenarioId');
  }

  Future<Map<String, dynamic>> calculateWB(
      int aircraftId, int profileId, Map<String, dynamic> data) async {
    final response = await _dio.post(
        '/aircraft/$aircraftId/wb/profiles/$profileId/calculate',
        data: data);
    return response.data;
  }

  // --- Aircraft Equipment ---

  // --- Imagery ---

  Future<Map<String, dynamic>> getImageryCatalog() async {
    final response = await _dio.get('/imagery/catalog');
    return response.data;
  }

  Future<Uint8List?> getGfaImage(String type, String region,
      {int forecastHour = 3}) async {
    try {
      final response = await _dio.get(
        '/imagery/gfa/$type/$region',
        queryParameters: {'forecastHour': forecastHour},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> getProgChart(String type, {int forecastHour = 6}) async {
    try {
      final response = await _dio.get(
        '/imagery/prog/$type',
        queryParameters: {'forecastHour': forecastHour},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> getConvectiveOutlook(int day,
      {String type = 'cat'}) async {
    try {
      final response = await _dio.get(
        '/imagery/convective/$day',
        queryParameters: {'type': type},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> getWindsAloftChart(String level,
      {String area = 'a', int forecastHour = 6}) async {
    try {
      final response = await _dio.get(
        '/imagery/winds/$level',
        queryParameters: {'area': area, 'forecastHour': forecastHour},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> getIcingChart(String param,
      {String level = 'max', int forecastHour = 0}) async {
    try {
      final response = await _dio.get(
        '/imagery/icing/$param',
        queryParameters: {'level': level, 'forecastHour': forecastHour},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAdvisories(String type,
      {int? forecastHour}) async {
    try {
      final response = await _dio.get(
        '/imagery/advisories/$type',
        queryParameters: {
          if (forecastHour != null) 'fore': forecastHour,
        },
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTfrs() async {
    try {
      final response = await _dio.get(
        '/imagery/tfrs',
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPireps({String? bbox, int? age}) async {
    try {
      final response = await _dio.get(
        '/imagery/pireps',
        queryParameters: {
          if (bbox != null) 'bbox': bbox,
          if (age != null) 'age': age,
        },
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  // --- CIFP ---

  Future<List<dynamic>> getApproaches(String airportId) async {
    final response = await _dio.get('/cifp/$airportId/approaches');
    return response.data;
  }

  Future<Map<String, dynamic>> getChartData(
      String airportId, int approachId) async {
    final response =
        await _dio.get('/cifp/$airportId/chart-data/$approachId');
    return response.data;
  }

  // --- Logbook ---

  Future<Map<String, dynamic>> getLogbookEntries({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get('/logbook', queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getLogbookSummary() async {
    final response = await _dio.get('/logbook/summary');
    return response.data;
  }

  Future<Map<String, dynamic>> getLogbookEntry(int id) async {
    final response = await _dio.get('/logbook/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createLogbookEntry(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/logbook', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateLogbookEntry(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/logbook/$id', data: data);
    return response.data;
  }

  Future<void> deleteLogbookEntry(int id) async {
    await _dio.delete('/logbook/$id');
  }

  Future<Map<String, dynamic>> getLogbookExperienceReport({
    String? period,
  }) async {
    final response = await _dio.get('/logbook/experience-report',
        queryParameters: {
          if (period != null) 'period': period,
        });
    return response.data;
  }

  // --- Endorsements ---

  Future<Map<String, dynamic>> getEndorsements({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get('/endorsements', queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getEndorsement(int id) async {
    final response = await _dio.get('/endorsements/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createEndorsement(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/endorsements', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateEndorsement(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/endorsements/$id', data: data);
    return response.data;
  }

  Future<void> deleteEndorsement(int id) async {
    await _dio.delete('/endorsements/$id');
  }

  // --- Certificates ---

  Future<Map<String, dynamic>> getCertificates({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get('/certificates', queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getCertificate(int id) async {
    final response = await _dio.get('/certificates/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createCertificate(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/certificates', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateCertificate(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/certificates/$id', data: data);
    return response.data;
  }

  Future<void> deleteCertificate(int id) async {
    await _dio.delete('/certificates/$id');
  }

  // --- Currency ---

  Future<List<dynamic>> getLogbookCurrency() async {
    final response = await _dio.get('/logbook/currency');
    return response.data;
  }

  // --- Import ---

  Future<Map<String, dynamic>> importLogbook({
    required Uint8List fileBytes,
    required String fileName,
    required String source,
    bool preview = true,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'source': source,
      'preview': preview.toString(),
    });
    final response = await _dio.post(
      '/logbook/import',
      data: formData,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    return response.data;
  }

  // --- Registry ---

  Future<Map<String, dynamic>?> lookupRegistry(String nNumber) async {
    try {
      final response = await _dio.get('/registry/lookup/$nNumber');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
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

  // --- Documents ---

  Future<List<dynamic>> getDocuments({int? folderId, int? aircraftId}) async {
    final response = await _dio.get('/documents', queryParameters: {
      if (folderId != null) 'folder_id': folderId,
      if (aircraftId != null) 'aircraft_id': aircraftId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getDocumentById(int id) async {
    final response = await _dio.get('/documents/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> getDocumentDownloadUrl(int id) async {
    final response = await _dio.get('/documents/$id/download');
    return response.data;
  }

  Future<Uint8List> downloadDocumentBytes(int id) async {
    final response = await _dio.get<List<int>>(
      '/documents/$id/download',
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<Map<String, dynamic>> uploadDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    int? aircraftId,
    int? folderId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName,
          contentType: DioMediaType.parse(mimeType)),
      if (aircraftId != null) 'aircraft_id': aircraftId.toString(),
      if (folderId != null) 'folder_id': folderId.toString(),
    });
    final response = await _dio.post(
      '/documents/upload',
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> updateDocument(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/documents/$id', data: data);
    return response.data;
  }

  Future<void> deleteDocument(int id) async {
    await _dio.delete('/documents/$id');
  }

  Future<List<dynamic>> getDocumentFolders({int? aircraftId}) async {
    final response = await _dio.get('/documents/folders', queryParameters: {
      if (aircraftId != null) 'aircraft_id': aircraftId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> createDocumentFolder(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/documents/folders', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateDocumentFolder(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/documents/folders/$id', data: data);
    return response.data;
  }

  Future<void> deleteDocumentFolder(int id) async {
    await _dio.delete('/documents/folders/$id');
  }

  // --- Traffic ---

  Future<List<Map<String, dynamic>>?> getTrafficNearby({
    required double lat,
    required double lon,
    double radius = 30,
  }) async {
    try {
      final response = await _dio.get('/traffic/nearby', queryParameters: {
        'lat': lat,
        'lon': lon,
        'radius': radius,
      });
      final data = response.data;
      if (data is Map && data['targets'] is List) {
        return (data['targets'] as List).cast<Map<String, dynamic>>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // --- Filing ---

  Future<Map<String, dynamic>> validateFiling(int flightId) async {
    final response = await _dio.get('/filing/$flightId/validate');
    return response.data;
  }

  Future<Map<String, dynamic>> fileFlight(int flightId) async {
    final response = await _dio.post('/filing/$flightId/file');
    return response.data;
  }

  Future<Map<String, dynamic>> amendFlight(int flightId) async {
    final response = await _dio.post('/filing/$flightId/amend');
    return response.data;
  }

  Future<Map<String, dynamic>> cancelFiling(int flightId) async {
    final response = await _dio.post('/filing/$flightId/cancel');
    return response.data;
  }

  Future<Map<String, dynamic>> closeFiling(int flightId) async {
    final response = await _dio.post('/filing/$flightId/close');
    return response.data;
  }

  Future<Map<String, dynamic>> getFilingStatus(int flightId) async {
    final response = await _dio.get('/filing/$flightId/status');
    return response.data;
  }
}

/// Riverpod provider for the API client
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref: ref);
});

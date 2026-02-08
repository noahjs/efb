import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base API client for the NestJS backend
class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? 'http://localhost:3001/api',
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

  Future<Map<String, dynamic>> copyFlight(int id) async {
    final response = await _dio.post('/flights/$id/copy');
    return response.data;
  }
}

/// Riverpod provider for the API client
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

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
}

/// Riverpod provider for the API client
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

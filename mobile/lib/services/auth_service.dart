import 'package:dio/dio.dart';
import '../core/config/app_config.dart';

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: json['user'] as Map<String, dynamic>,
    );
  }
}

/// Separate auth service with its own Dio instance to avoid
/// circular dependency with the auth interceptor.
class AuthService {
  final Dio _dio;

  AuthService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: '${AppConfig.apiBaseUrl}/api/auth',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> loginWithGoogle(String idToken) async {
    final response = await _dio.post('/google', data: {
      'id_token': idToken,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> loginWithApple({
    required String identityToken,
    String? name,
  }) async {
    final response = await _dio.post('/apple', data: {
      'identity_token': identityToken,
      if (name != null) 'name': name,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    final response = await _dio.post('/refresh', data: {
      'refresh_token': refreshToken,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<void> logout(String accessToken) async {
    try {
      await _dio.post(
        '/logout',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
    } catch (_) {
      // Best-effort — if logout fails, we still clear local state
    }
  }
}

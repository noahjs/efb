import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../core/config/app_config.dart';
import 'auth_service.dart';

const _keyAccessToken = 'access_token';
const _keyRefreshToken = 'refresh_token';
const _keyUserId = 'user_id';
const _keyUserName = 'user_name';
const _keyUserEmail = 'user_email';

class AuthState {
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => accessToken != null;

  const AuthState({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
    bool? isLoading,
    String? error,
    bool clearTokens = false,
    bool clearError = false,
  }) {
    return AuthState(
      accessToken: clearTokens ? null : (accessToken ?? this.accessToken),
      refreshToken: clearTokens ? null : (refreshToken ?? this.refreshToken),
      user: clearTokens ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  late final FlutterSecureStorage _storage;

  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);
    _storage = ref.read(secureStorageProvider);
    _init();
    return const AuthState();
  }

  Future<void> _init() async {
    await _loadTokens();
    if (!state.isAuthenticated && AppConfig.devAutoLogin) {
      await login(email: 'demo@efb.app', password: 'demo1234');
    }
  }

  Future<void> _loadTokens() async {
    try {
      final accessToken = await _storage.read(key: _keyAccessToken);
      final refreshToken = await _storage.read(key: _keyRefreshToken);
      final userId = await _storage.read(key: _keyUserId);
      final userName = await _storage.read(key: _keyUserName);
      final userEmail = await _storage.read(key: _keyUserEmail);

      if (accessToken != null && refreshToken != null) {
        state = AuthState(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: {
            'id': userId,
            'name': userName,
            'email': userEmail,
          },
        );
      }
    } catch (_) {
      // Secure storage unavailable (e.g. web) — skip token restore
    }
  }

  Future<void> _saveTokens(AuthResponse response) async {
    try {
      await _storage.write(key: _keyAccessToken, value: response.accessToken);
      await _storage.write(
          key: _keyRefreshToken, value: response.refreshToken);
      await _storage.write(
          key: _keyUserId, value: response.user['id'] as String?);
      await _storage.write(
          key: _keyUserName, value: response.user['name'] as String?);
      await _storage.write(
          key: _keyUserEmail, value: response.user['email'] as String?);
    } catch (_) {
      // Secure storage unavailable (e.g. web)
    }
  }

  Future<void> _clearTokens() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyUserName);
      await _storage.delete(key: _keyUserEmail);
    } catch (_) {
      // Secure storage unavailable (e.g. web)
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      await _saveTokens(response);
      state = AuthState(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return true;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Registration failed';
      state = state.copyWith(
        isLoading: false,
        error: message is List ? message.first.toString() : message.toString(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Registration failed');
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );
      await _saveTokens(response);
      state = AuthState(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return true;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Login failed';
      state = state.copyWith(
        isLoading: false,
        error: message is List ? message.first.toString() : message.toString(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Login failed');
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final googleUser = await GoogleSignIn(
        clientId: AppConfig.googleClientId,
      ).signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      final auth = await googleUser.authentication;
      if (auth.idToken == null) {
        state =
            state.copyWith(isLoading: false, error: 'Google sign-in failed');
        return false;
      }
      final response = await _authService.loginWithGoogle(auth.idToken!);
      await _saveTokens(response);
      state = AuthState(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed');
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      if (credential.identityToken == null) {
        state =
            state.copyWith(isLoading: false, error: 'Apple sign-in failed');
        return false;
      }
      final name = [
        credential.givenName,
        credential.familyName,
      ].where((s) => s != null && s.isNotEmpty).join(' ');

      final response = await _authService.loginWithApple(
        identityToken: credential.identityToken!,
        name: name.isNotEmpty ? name : null,
      );
      await _saveTokens(response);
      state = AuthState(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Apple sign-in failed');
      return false;
    }
  }

  Future<bool> refreshTokens() async {
    if (state.refreshToken == null) return false;
    try {
      final response = await _authService.refresh(state.refreshToken!);
      await _saveTokens(response);
      state = AuthState(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> updateAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
    state = state.copyWith(accessToken: token);
  }

  Future<void> logout() async {
    if (state.accessToken != null) {
      await _authService.logout(state.accessToken!);
    }
    await _clearTokens();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

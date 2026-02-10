import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';

/// Dio interceptor that attaches Bearer tokens and handles 401 refresh.
class AuthInterceptor extends Interceptor {
  final Ref _ref;
  bool _isRefreshing = false;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authProvider).accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final success =
          await _ref.read(authProvider.notifier).refreshTokens();
      if (success) {
        // Retry original request with new token
        final token = _ref.read(authProvider).accessToken;
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $token';

        final dio = Dio();
        final response = await dio.fetch(opts);
        return handler.resolve(response);
      } else {
        // Refresh failed — logout
        await _ref.read(authProvider.notifier).logout();
        return handler.next(err);
      }
    } catch (_) {
      await _ref.read(authProvider.notifier).logout();
      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}

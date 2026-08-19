import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_error.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

typedef RefreshTokens = Future<({String accessToken, String refreshToken})?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required RefreshTokens refreshTokens,
    required Set<String> skipAuthPaths,
  }) : _tokenStore = tokenStore,
       _refreshTokens = refreshTokens,
       _skipAuthPaths = skipAuthPaths;

  final TokenStore _tokenStore;
  final RefreshTokens _refreshTokens;
  final Set<String> _skipAuthPaths;
  bool _refreshing = false;

  bool _shouldSkip(RequestOptions options) {
    return _skipAuthPaths.any(options.path.contains);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_shouldSkip(options)) {
      final token = await _tokenStore.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 || _shouldSkip(err.requestOptions)) {
      handler.next(err);
      return;
    }
    if (_refreshing) {
      handler.next(err);
      return;
    }
    _refreshing = true;
    try {
      final pair = await _refreshTokens();
      if (pair == null) {
        handler.next(err);
        return;
      }
      final request = err.requestOptions;
      request.headers['Authorization'] = 'Bearer ${pair.accessToken}';
      final dio = err.requestOptions.extra['dio'] as Dio?;
      if (dio == null) {
        handler.next(err);
        return;
      }
      final response = await dio.fetch(request);
      handler.resolve(response);
    } on DioException catch (refreshError) {
      handler.next(refreshError);
    } finally {
      _refreshing = false;
    }
  }
}

ApiError mapDioError(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    return ApiError.fromBody(data, statusCode: error.response?.statusCode);
  }
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout) {
    return const ApiError(
      code: 'network',
      message: 'Check your connection and try again',
    );
  }
  return ApiError(
    code: 'unknown',
    message: error.message ?? 'Something went wrong',
    statusCode: error.response?.statusCode,
  );
}

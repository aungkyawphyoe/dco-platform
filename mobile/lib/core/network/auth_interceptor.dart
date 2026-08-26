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
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return const ApiError(
        code: 'network',
        message: 'Check your connection and try again',
      );
    case DioExceptionType.badCertificate:
      return const ApiError(
        code: 'bad_certificate',
        message: 'The connection could not be verified',
      );
    case DioExceptionType.cancel:
      return const ApiError(code: 'cancelled', message: 'Request cancelled');
    case DioExceptionType.badResponse:
      return _mapStatus(error.response?.statusCode);
    case DioExceptionType.unknown:
      return ApiError(
        code: 'unknown',
        message: error.message ?? 'Something went wrong',
        statusCode: error.response?.statusCode,
      );
  }
}

ApiError _mapStatus(int? statusCode) {
  if (statusCode == null) {
    return const ApiError(code: 'unknown', message: 'Something went wrong');
  }
  if (statusCode >= 500) {
    return ApiError(
      code: 'server',
      message: 'Server error. Try again shortly',
      statusCode: statusCode,
    );
  }
  return switch (statusCode) {
    400 => const ApiError(code: 'validation', message: 'The request was invalid'),
    401 => const ApiError(code: 'unauthenticated', message: 'Session expired. Sign in again'),
    403 => const ApiError(code: 'forbidden', message: 'You do not have access to this'),
    404 => const ApiError(code: 'not_found', message: 'Not found'),
    409 => const ApiError(code: 'conflict', message: 'That change conflicts with a newer one'),
    413 => const ApiError(code: 'media_too_large', message: 'File exceeds the 15MB limit'),
    422 => const ApiError(code: 'validation', message: 'Some details need fixing'),
    429 => const ApiError(code: 'rate_limited', message: 'Too many attempts. Try again shortly'),
    _ => ApiError(
      code: 'unknown',
      message: 'Something went wrong',
      statusCode: statusCode,
    ),
  };
}

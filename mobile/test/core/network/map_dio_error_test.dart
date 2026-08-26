import 'package:dco_mobile/core/network/api_error.dart';
import 'package:dco_mobile/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ApiError map(DioExceptionType type, {int? statusCode, Object? body}) {
    return mapDioError(
      DioException(
        requestOptions: RequestOptions(path: '/v1/test'),
        type: type,
        response: statusCode == null && body == null
            ? null
            : Response<Object?>(
                requestOptions: RequestOptions(path: '/v1/test'),
                statusCode: statusCode,
                data: body,
              ),
      ),
    );
  }

  group('mapDioError', () {
    test('connection failures map to network', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final error = map(type);
        expect(error.code, 'network', reason: '$type should be network');
      }
    });

    test('bad certificate maps to bad_certificate', () {
      expect(map(DioExceptionType.badCertificate).code, 'bad_certificate');
    });

    test('cancel maps to cancelled', () {
      expect(map(DioExceptionType.cancel).code, 'cancelled');
    });

    test('server error bodies win over status fallback', () {
      final error = map(
        DioExceptionType.badResponse,
        statusCode: 422,
        body: {
          'error': {'code': 'mileage_decrease', 'message': 'Mileage cannot decrease'},
        },
      );
      expect(error.code, 'mileage_decrease');
      expect(error.message, 'Mileage cannot decrease');
      expect(error.statusCode, 422);
    });

    test('unparseable bodies fall back to status-based messages', () {
      expect(
        map(DioExceptionType.badResponse, statusCode: 401, body: 'denied').code,
        'unauthenticated',
      );
      expect(
        map(DioExceptionType.badResponse, statusCode: 403, body: null).code,
        'forbidden',
      );
      expect(
        map(DioExceptionType.badResponse, statusCode: 404, body: null).code,
        'not_found',
      );
      expect(
        map(DioExceptionType.badResponse, statusCode: 409, body: null).code,
        'conflict',
      );
      expect(
        map(DioExceptionType.badResponse, statusCode: 413, body: null).code,
        'media_too_large',
      );
      expect(
        map(DioExceptionType.badResponse, statusCode: 422, body: null).code,
        'validation',
      );
      expect(
        map(DioExceptionType.badResponse, statusCode: 429, body: null).code,
        'rate_limited',
      );
    });

    test('5xx responses report server errors', () {
      final error = map(DioExceptionType.badResponse, statusCode: 503, body: 'down');
      expect(error.code, 'server');
      expect(error.statusCode, 503);
    });

    test('unknown errors keep their message', () {
      final error = mapDioError(
        DioException(
          requestOptions: RequestOptions(path: '/v1/test'),
          type: DioExceptionType.unknown,
          message: 'socket closed',
        ),
      );
      expect(error.code, 'unknown');
      expect(error.message, 'socket closed');
    });

    test('ApiError.fromBody tolerates malformed payloads', () {
      final error = ApiError.fromBody(const {'error': 'weird'}, statusCode: 400);
      expect(error.code, 'unknown');
      expect(error.statusCode, 400);
    });
  });
}

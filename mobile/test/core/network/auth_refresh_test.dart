import 'dart:async';

import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/network/dio_client.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryTokenStore tokens;
  setUp(() async {
    tokens = MemoryTokenStore();
    await tokens.writeSession(
      accessToken: 'old',
      refreshToken: 'refresh',
      userJson: '{}',
    );
  });

  Dio client(
    Future<({String accessToken, String refreshToken})?> Function() refresh,
  ) {
    final dio = DioClient(
      config: const AppConfig(
        apiBaseUrl: 'https://api.test/v1',
        jwtOwnerAud: 'dco-owner',
        mockAuth: false,
        analyticsEnabled: false,
      ),
      tokenStore: tokens,
      refreshTokens: refresh,
    ).dio;
    addTearDown(() => dio.close(force: true));
    return dio;
  }

  void reject(RequestOptions options, RequestInterceptorHandler handler) =>
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
        true,
      );

  test(
    'concurrent 401s share one refresh and both retry successfully',
    () async {
      var refreshes = 0;
      final started = Completer<void>();
      final finish = Completer<void>();
      final dio = client(() async {
        refreshes++;
        started.complete();
        await finish.future;
        await tokens.writeSession(
          accessToken: 'new',
          refreshToken: 'rotated',
          userJson: '{}',
        );
        return (accessToken: 'new', refreshToken: 'rotated');
      });
      var rejected = 0;
      final bothRejected = Completer<void>();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.headers['Authorization'] == 'Bearer old') {
              reject(options, handler);
              if (++rejected == 2) bothRejected.complete();
            } else {
              handler.resolve(
                Response(requestOptions: options, statusCode: 200),
              );
            }
          },
        ),
      );
      final responses = Future.wait([dio.get('/one'), dio.get('/two')]);
      await bothRejected.future;
      await started.future;
      finish.complete();
      expect((await responses).map((r) => r.statusCode), [200, 200]);
      expect(refreshes, 1);
    },
  );

  test('a retried 401 stops after one refresh', () async {
    var refreshes = 0;
    var requests = 0;
    final dio = client(() async {
      refreshes++;
      await tokens.writeSession(
        accessToken: 'new',
        refreshToken: 'rotated',
        userJson: '{}',
      );
      return (accessToken: 'new', refreshToken: 'rotated');
    });
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          reject(options, handler);
        },
      ),
    );
    await expectLater(dio.get('/private'), throwsA(isA<DioException>()));
    expect(refreshes, 1);
    expect(requests, 2);
  });

  test(
    'offline refresh preserves tokens and a later request can recover',
    () async {
      var online = false;
      final dio = client(() async {
        if (!online) {
          throw DioException(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            type: DioExceptionType.connectionError,
          );
        }
        await tokens.writeSession(
          accessToken: 'new',
          refreshToken: 'rotated',
          userJson: '{}',
        );
        return (accessToken: 'new', refreshToken: 'rotated');
      });
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.headers['Authorization'] == 'Bearer old') {
              reject(options, handler);
            } else {
              handler.resolve(
                Response(requestOptions: options, statusCode: 200),
              );
            }
          },
        ),
      );
      await expectLater(
        dio.get('/private'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
      expect(await tokens.readRefreshToken(), 'refresh');
      online = true;
      expect((await dio.get('/private')).statusCode, 200);
      expect(await tokens.readRefreshToken(), 'rotated');
    },
  );
}

import 'dart:async';
import 'package:dco_mobile/core/network/auth_interceptor.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final unauthorized in [false, true]) {
    test(
      'late response unauthorized=$unauthorized is cancelled after account cleanup',
      () async {
        final tokens = MemoryTokenStore();
        await tokens.writeSession(
          accessToken: 'user-1',
          refreshToken: 'user-1',
          userJson: '{}',
        );
        var refreshCalls = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        addTearDown(() => dio.close(force: true));
        dio.interceptors.add(
          AuthInterceptor(
            tokenStore: tokens,
            skipAuthPaths: {},
            refreshTokens: () async {
              refreshCalls++;
              return null;
            },
          ),
        );
        final entered = Completer<void>();
        late RequestOptions request;
        late RequestInterceptorHandler pending;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              pending = handler;
              entered.complete();
            },
          ),
        );
        final response = dio.get('/private-record');
        await entered.future;
        await tokens.clear();
        await tokens.writeSession(
          accessToken: 'user-2',
          refreshToken: 'user-2',
          userJson: '{}',
        );
        final rejected = expectLater(
          response,
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.cancel,
            ),
          ),
        );
        if (unauthorized) {
          pending.reject(
            DioException(
              requestOptions: request,
              response: Response(requestOptions: request, statusCode: 401),
              type: DioExceptionType.badResponse,
            ),
            true,
          );
        } else {
          pending.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {'private': 'user-1'},
            ),
            true,
          );
        }
        await rejected;
        expect(refreshCalls, 0);
        expect(await tokens.readAccessToken(), 'user-2');
      },
    );
  }
}

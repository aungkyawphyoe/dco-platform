import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/features/auth/data/repositories/account_security_repository_impl.dart';
import 'package:dco_mobile/features/auth/domain/repositories/account_security_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingSink extends NoOpAnalyticsSink {
  final events = <Map<String, Object?>>[];
  @override
  Future<void> logEvent(String name, Map<String, Object?> parameters) async {
    events.add(parameters);
  }
}

void main() {
  late Dio dio;
  late RecordingSink sink;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    sink = RecordingSink();
  });
  tearDown(() => dio.close());
  Matcher code(String value) =>
      isA<AccountSecurityException>().having((e) => e.code, 'code', value);

  void fail(Object? data, {int? status = 503}) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: status == null
                  ? DioExceptionType.connectionError
                  : DioExceptionType.badResponse,
              response: status == null
                  ? null
                  : Response(
                      requestOptions: options,
                      statusCode: status,
                      data: data,
                    ),
            ),
          );
        },
      ),
    );
  }

  test('production missing-provider response never opens browser', () async {
    fail({
      'error': {'code': 'provider_not_configured'},
    });
    var opened = false;
    final repo = AccountSecurityRepositoryImpl(
      dio,
      analytics: Analytics(sink),
      authenticate: ({required url, required callbackUrlScheme}) async {
        opened = true;
        return '';
      },
    );
    await expectLater(
      repo.authorize('google'),
      throwsA(code('provider_not_configured')),
    );
    expect(opened, false);
    expect(sink.events.single['outcome'], 'provider_not_configured');
  });

  for (final data in [
    null,
    '<html>unavailable</html>',
    {'error': 'bad gateway'},
    {
      'error': {'code': 123},
    },
  ]) {
    test('malformed server error maps safely: $data', () async {
      fail(data);
      await expectLater(
        AccountSecurityRepositoryImpl(dio).request('/auth/social/complete'),
        throwsA(code('server_unavailable')),
      );
    });
  }
  test('transport failure remains distinct from a server response', () async {
    fail(null, status: null);
    await expectLater(
      AccountSecurityRepositoryImpl(dio).authorize('google'),
      throwsA(code('network')),
    );
  });

  for (final provider in ['google', 'apple']) {
    test(
      '$provider cancellation retries with a fresh flow and sanitized events',
      () async {
        var starts = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              starts++;
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'authorization_url':
                        'https://provider.test/?sensitive=hidden',
                    'flow_id': 'flow-$starts',
                    'secret': 'private-$starts',
                  },
                ),
              );
            },
          ),
        );
        var opens = 0;
        final repo = AccountSecurityRepositoryImpl(
          dio,
          analytics: Analytics(sink),
          authenticate: ({required url, required callbackUrlScheme}) async {
            expect(callbackUrlScheme, 'dco-auth');
            if (++opens == 1) throw PlatformException(code: 'CANCELED');
            return 'dco-auth://callback?flow_id=flow-2';
          },
        );
        await expectLater(
          repo.authorize(provider),
          throwsA(isA<PlatformException>()),
        );
        expect(await repo.authorize(provider), {
          'flow_id': 'flow-2',
          'secret': 'private-2',
        });
        expect(starts, 2);
        expect(sink.events.map((e) => e['outcome']), [
          'success',
          'cancelled',
          'success',
          'success',
        ]);
        for (final event in sink.events) {
          expect(
            event.keys,
            unorderedEquals(['stage', 'outcome', 'elapsed_ms']),
          );
        }
        expect(sink.events.toString(), isNot(contains('private')));
        expect(sink.events.toString(), isNot(contains('sensitive')));
      },
    );
  }

  test('mismatched browser callback is rejected', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'authorization_url': 'https://provider.test',
                'flow_id': 'expected',
                'secret': 'secret',
              },
            ),
          );
        },
      ),
    );
    final repo = AccountSecurityRepositoryImpl(
      dio,
      authenticate: ({required url, required callbackUrlScheme}) async =>
          'dco-auth://callback?flow_id=wrong',
    );
    await expectLater(repo.authorize('google'), throwsA(code('invalid_flow')));
  });

  test('invalid start payload never launches browser', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'authorization_url': 'http://provider.test'},
            ),
          );
        },
      ),
    );
    final repo = AccountSecurityRepositoryImpl(
      dio,
      authenticate: ({required url, required callbackUrlScheme}) async =>
          throw StateError('must not open'),
    );
    await expectLater(repo.authorize('google'), throwsA(code('invalid_flow')));
  });
}

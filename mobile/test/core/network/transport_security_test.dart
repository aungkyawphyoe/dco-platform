import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/network/dio_client.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release API configuration requires HTTPS and rejects embedded credentials', () {
    expect(() => validateApiBaseUrl('http://localhost/v1', releaseMode: true), throwsStateError);
    expect(() => validateApiBaseUrl('https://user:pass@api.test/v1', releaseMode: true), throwsStateError);
    expect(() => validateApiBaseUrl('https://api.test/v1?token=secret', releaseMode: true), throwsStateError);
    validateApiBaseUrl('https://api.test/v1', releaseMode: true);
    validateApiBaseUrl('http://localhost/v1', releaseMode: false);
  });

  test('credentials stay on the API origin and redirect following is disabled', () async {
    final store = MemoryTokenStore();
    await store.writeSession(accessToken: 'secret', refreshToken: 'refresh', userJson: '{}');
    final client = DioClient(
      config: const AppConfig(apiBaseUrl: 'https://api.test/v1', jwtOwnerAud: 'owner', mockAuth: false, analyticsEnabled: false),
      tokenStore: store,
      refreshTokens: () async => null,
    );
    final seen = <RequestOptions>[];
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      seen.add(options);
      handler.resolve(Response(requestOptions: options, statusCode: 200));
    }));
    await client.dio.get('/me');
    await client.dio.get('https://files.test/receipt', options: Options(headers: {'authorization': 'must-be-removed'}));
    await client.dio.get('/auth/login');
    expect(seen[0].headers['Authorization'], 'Bearer secret');
    expect(seen[0].followRedirects, false);
    expect(seen[1].headers.keys.any((key) => key.toLowerCase() == 'authorization'), false);
    expect(seen[2].headers['Authorization'], isNull);
  });
}

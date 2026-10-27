import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/network/dio_client.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bodyless mutations omit JSON content type; JSON bodies keep it',
    () async {
      final client = DioClient(
        config: const AppConfig(
          apiBaseUrl: 'https://api.test/v1',
          jwtOwnerAud: 'owner',
          mockAuth: false,
          analyticsEnabled: false,
        ),
        tokenStore: MemoryTokenStore(),
        refreshTokens: () async => null,
      );
      addTearDown(() => client.dio.close());
      final seen = <RequestOptions>[];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            seen.add(options);
            handler.resolve(Response(requestOptions: options, statusCode: 200));
          },
        ),
      );
      await client.dio.delete('/vehicles/v/shares/s');
      await client.dio.post('/vehicles/v/invitations/i/resend');
      await client.dio.patch(
        '/vehicles/v/shares/s',
        data: {'access_level': 'view'},
      );
      expect(seen[0].contentType, isNull);
      expect(seen[1].contentType, isNull);
      expect(seen[2].contentType, Headers.jsonContentType);
    },
  );
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dco_mobile/features/pricing/data/play_billing_backend.dart';
import 'package:dco_mobile/features/pricing/domain/play_billing.dart';

void main() {
  test(
    'checkout fails closed when the signing public key is not bundled',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'enabled': true,
                  'can_purchase': true,
                  'account_id': 'hash',
                  'package_name': 'com.dco.dco_mobile',
                  'license_kid': 'production-key',
                },
              ),
            );
          },
        ),
      );
      expect((await PlayBillingBackend(dio, {}).eligibility()).enabled, false);
      expect(
        (await PlayBillingBackend(dio, {
          'production-key',
        }).eligibility()).enabled,
        true,
      );
      dio.close();
    },
  );
  test(
    'verification requires explicit server verification and preserves safe error codes',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'entitled': true, 'acknowledged': true},
              ),
            );
          },
        ),
      );
      await expectLater(
        PlayBillingBackend(dio, {}).verify('token'),
        throwsA(isA<BillingFailure>()),
      );
      dio.close();
    },
  );
}

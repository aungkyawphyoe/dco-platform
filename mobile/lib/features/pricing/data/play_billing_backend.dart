import 'package:dio/dio.dart';
import '../domain/play_billing.dart';

class PlayBillingBackend implements BillingBackend {
  PlayBillingBackend(this._dio, this._licenseKids);
  final Set<String> _licenseKids;
  final Dio _dio;
  @override
  Future<BillingEligibility> eligibility() async {
    final data = (await _dio.get<Map<String, dynamic>>(
      '/me/play-billing',
    )).data!;
    return BillingEligibility(
      enabled:
          data['enabled'] == true && _licenseKids.contains(data['license_kid']),
      canPurchase: data['can_purchase'] == true,
      accountId: data['account_id'] as String,
      packageName: data['package_name'] as String,
    );
  }

  @override
  Future<BillingVerification> verify(String token) async {
    try {
      final data = (await _dio.post<Map<String, dynamic>>(
        '/me/play-purchases',
        data: {'purchase_token': token},
      )).data!;
      if (data['verified'] != true) {
        throw const BillingFailure('verification_pending');
      }
      return BillingVerification(
        entitled: data['entitled'] == true,
        acknowledged: data['acknowledged'] == true,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      throw BillingFailure(
        data is Map && data['error'] is Map
            ? data['error']['code'] as String? ?? 'verification_pending'
            : 'verification_pending',
      );
    }
  }
}

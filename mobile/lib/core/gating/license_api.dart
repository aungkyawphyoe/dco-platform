import 'package:dio/dio.dart';

/// `GET /v1/me/license` — issues the offline entitlement license
/// (`architecture/feature-gating.md` §5.1). Returns the compact EdDSA
/// JWT; verification happens in [LicenseVerifier], never here.
class LicenseApi {
  LicenseApi(this._dio);

  final Dio _dio;

  Future<String> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/license');
    final data = response.data;
    final license = data?['license'];
    if (license is! String || license.isEmpty) {
      throw const FormatException('Empty license response');
    }
    return license;
  }
}

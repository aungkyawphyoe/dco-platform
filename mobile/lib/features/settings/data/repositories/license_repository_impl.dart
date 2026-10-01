import 'package:dco_mobile/features/settings/domain/repositories/license_repository.dart';
import 'package:dio/dio.dart';

import '../../../../core/entities/driving_license.dart';
import '../../../../core/media/media_api.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/auth_interceptor.dart';

class LicenseRepositoryImpl implements LicenseRepository {
  LicenseRepositoryImpl(this._dio, this._mediaApi);

  final Dio _dio;
  final MediaApi _mediaApi;

  @override
  Future<DrivingLicense?> getMyLicense() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/me/license',
      );
      return DrivingLicense.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw mapDioError(error);
    }
  }

  @override
  Future<DrivingLicense> upsertLicense({
    String? licenseNumber,
    String? issuingCountry,
    required String expiryDate,
    String? categories,
    String? frontMediaId,
    String? backMediaId,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/users/me/license',
        data: {
          'license_number': licenseNumber,
          'issuing_country': issuingCountry,
          'expiry_date': expiryDate,
          'categories': categories,
          'front_media_id': frontMediaId,
          'back_media_id': backMediaId,
        },
      );
      return DrivingLicense.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<String> uploadLicensePhoto(String side, List<int> bytes) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'license_$side.jpg'),
        'side': side,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/users/me/license/media',
        data: formData,
      );
      return response.data!['media_id'] as String;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<DrivingLicense?> getMemberLicense(String userId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/$userId/license',
      );
      return DrivingLicense.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      if (error.response?.statusCode == 403) return null;
      throw mapDioError(error);
    }
  }
}

/// Memory-backed stand-in used while `DCO_MOCK_AUTH` is enabled.
class MockLicenseRepository implements LicenseRepository {
  DrivingLicense? _license;

  @override
  Future<DrivingLicense?> getMyLicense() async => _license;

  @override
  Future<DrivingLicense> upsertLicense({
    String? licenseNumber,
    String? issuingCountry,
    required String expiryDate,
    String? categories,
    String? frontMediaId,
    String? backMediaId,
  }) async {
    final now = DateTime.now();
    _license = DrivingLicense(
      id: _license?.id ?? 'mock-license',
      userId: 'mock-user',
      licenseNumber: licenseNumber,
      issuingCountry: issuingCountry,
      expiryDate: DateTime.parse(expiryDate),
      categories: categories,
      frontMediaId: frontMediaId ?? _license?.frontMediaId,
      backMediaId: backMediaId ?? _license?.backMediaId,
      createdAt: _license?.createdAt ?? now,
      updatedAt: now,
    );
    return _license!;
  }

  @override
  Future<String> uploadLicensePhoto(String side, List<int> bytes) async =>
      'mock_${side}_media_id';

  @override
  Future<DrivingLicense?> getMemberLicense(String userId) async => null;
}

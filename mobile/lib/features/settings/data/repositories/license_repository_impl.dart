import 'package:dco_mobile/features/settings/domain/repositories/license_repository.dart';
import 'package:dio/dio.dart';

import '../../../../core/entities/driving_license.dart';
import '../../../../core/network/auth_interceptor.dart';

class LicenseRepositoryImpl implements LicenseRepository {
  LicenseRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> deleteMyLicense() async {
    try {
      await _dio.delete<void>('/users/me/license');
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

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
    required String expiryDate,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/users/me/license',
        data: {
          'license_number': licenseNumber,
          'license_expiry_date': expiryDate.trim().isEmpty ? null : expiryDate,
        },
      );
      return DrivingLicense.fromJson(response.data!);
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
  Future<void> deleteMyLicense() async {
    _license = null;
  }

  @override
  Future<DrivingLicense?> getMyLicense() async => _license;

  @override
  Future<DrivingLicense> upsertLicense({
    String? licenseNumber,
    required String expiryDate,
  }) async {
    final now = DateTime.now();
    _license = DrivingLicense(
      id: _license?.id ?? 'mock-license',
      userId: 'mock-user',
      licenseNumber: licenseNumber,
      expiryDate: expiryDate.trim().isEmpty ? null : DateTime.parse(expiryDate),
      createdAt: _license?.createdAt ?? now,
      updatedAt: now,
    );
    return _license!;
  }

  @override
  Future<DrivingLicense?> getMemberLicense(String userId) async => null;
}

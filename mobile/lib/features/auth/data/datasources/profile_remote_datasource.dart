import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../../domain/entities/session.dart';

abstract class ProfileRemoteDataSource {
  Future<User> get();
  Future<User> update(Map<String, dynamic> patch);
  Future<String> uploadPhoto(String filePath);
  Future<void> deleteAccount({required String password, String? reason});
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  });
}

class DioProfileRemoteDataSource implements ProfileRemoteDataSource {
  DioProfileRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<User> get() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/me/profile');
      return User.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<User> update(Map<String, dynamic> patch) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>('/users/me/profile', data: patch);
      return User.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<String> uploadPhoto(String filePath) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/users/me/profile/photo',
        data: formData,
      );
      return response.data!['url'] as String;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<void> deleteAccount({required String password, String? reason}) async {
    try {
      await _dio.post<void>(
        '/users/me/delete',
        data: {
          'password': password,
          if (reason != null) 'reason': reason,
        },
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    try {
      await _dio.post<void>(
        '/me/device-tokens',
        data: {'token': token, 'platform': platform},
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}

/// Debug stand-in used while `DCO_MOCK_AUTH` is enabled.
class MockProfileRemoteDataSource implements ProfileRemoteDataSource {
  User _user = const User(
    id: 'mock-user',
    email: 'owner@dco.dev',
    displayName: 'Mock Owner',
    role: 'owner',
    plan: 'free',
    status: 'active',
    emailVerified: true,
  );

  @override
  Future<User> get() async => _user;

  @override
  Future<User> update(Map<String, dynamic> patch) async {
    _user = User(
      id: _user.id,
      email: _user.email,
      displayName: (patch['display_name'] as String?) ?? _user.displayName,
      profilePhotoMediaId: _user.profilePhotoMediaId,
      contactPhone: (patch['contact_phone'] as String?) ?? _user.contactPhone,
      address: (patch['address'] as String?) ?? _user.address,
      role: _user.role,
      plan: _user.plan,
      status: _user.status,
      emailVerified: _user.emailVerified,
      activeVehicleId: (patch['active_vehicle_id'] as String?) ?? _user.activeVehicleId,
      vehicleLimit: _user.vehicleLimit,
    );
    return _user;
  }

  @override
  Future<String> uploadPhoto(String filePath) async => '';

  @override
  Future<void> deleteAccount({required String password, String? reason}) async {}

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {}
}

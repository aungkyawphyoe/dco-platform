import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../../domain/auth_failure.dart';
import '../../domain/entities/session.dart';
import 'auth_remote_datasource.dart';

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  DioAuthRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<Session> login({required String email, required String password, String? surface}) {
    return _session('POST', '/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
      if (surface != null) 'surface': surface,
    });
  }

  @override
  Future<Session> signup({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _session('POST', '/auth/signup', {
      'email': email.trim().toLowerCase(),
      'password': password,
      if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
    });
  }

  @override
  Future<Session> refresh({required String refreshToken}) {
    return _session('POST', '/auth/refresh', {'refresh_token': refreshToken});
  }

  @override
  Future<void> logout() => _empty('POST', '/auth/logout');

  @override
  Future<void> forgotPassword({required String email}) {
    return _empty('POST', '/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    });
  }

  @override
  Future<void> resetPassword({required String token, required String password}) {
    return _empty('POST', '/auth/reset-password', {
      'token': token,
      'password': password,
    });
  }

  @override
  Future<void> resendVerification() => _empty('POST', '/auth/resend-verification');

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return _empty('POST', '/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<Session> _session(String method, String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(method: method),
      );
      return Session.fromJson(response.data!);
    } on DioException catch (error) {
      throw _toFailure(error);
    }
  }

  Future<void> _empty(String method, String path, [Map<String, dynamic>? data]) async {
    try {
      await _dio.request<void>(
        path,
        data: data,
        options: Options(method: method),
      );
    } on DioException catch (error) {
      throw _toFailure(error);
    }
  }

  AuthFailure _toFailure(DioException error) {
    final mapped = mapDioError(error);
    if (mapped.code == 'network') {
      return NetworkAuthFailure(mapped.message);
    }
    return mapStatusToAuthFailure(mapped.statusCode, mapped.message);
  }
}

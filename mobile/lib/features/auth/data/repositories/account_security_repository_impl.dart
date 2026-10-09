import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../domain/repositories/account_security_repository.dart';

class AccountSecurityRepositoryImpl implements AccountSecurityRepository {
  AccountSecurityRepositoryImpl(this._dio);
  final Dio _dio;
  Future<Map<String, dynamic>> _call(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(method: method),
      );
      return response.data ?? {};
    } on DioException catch (e) {
      final data = e.response?.data;
      throw AccountSecurityException(
        data is Map
            ? (data['error']?['code'] as String? ?? 'unknown')
            : 'network',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) => _call('POST', path, body ?? {});
  @override
  Future<Map<String, dynamic>> profile() => _call('GET', '/me', null);
  @override
  Future<Map<String, dynamic>> connections() =>
      _call('GET', '/auth/connections', null);
  @override
  Future<Map<String, dynamic>> authorize(String provider) async {
    final flow = await request('/auth/social/$provider/start');
    final result = await FlutterWebAuth2.authenticate(
      url: flow['authorization_url'] as String,
      callbackUrlScheme: 'dco-auth',
    );
    final returned = Uri.parse(result);
    if (returned.scheme != 'dco-auth' ||
        returned.host != 'callback' ||
        returned.queryParameters['flow_id'] != flow['flow_id']) {
      throw const AccountSecurityException('invalid_flow');
    }
    return {'flow_id': flow['flow_id'], 'secret': flow['secret']};
  }
}

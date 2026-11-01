import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../../core/analytics/analytics.dart';

import '../../domain/repositories/account_security_repository.dart';

typedef BrowserAuthenticate =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
    });

class AccountSecurityRepositoryImpl implements AccountSecurityRepository {
  AccountSecurityRepositoryImpl(
    this._dio, {
    this.analytics = const Analytics(),
    BrowserAuthenticate? authenticate,
  }) : _authenticate = authenticate ?? _openBrowser;
  final Analytics analytics;
  final BrowserAuthenticate _authenticate;
  static Future<String> _openBrowser({
    required String url,
    required String callbackUrlScheme,
  }) => FlutterWebAuth2.authenticate(
    url: url,
    callbackUrlScheme: callbackUrlScheme,
  );

  Future<T> _observe<T>(String stage, Future<T> Function() action) async {
    final timer = Stopwatch()..start();
    var outcome = 'success';
    try {
      return await action();
    } catch (error) {
      outcome = switch (error) {
        AccountSecurityException(code: 'provider_not_configured') =>
          'provider_not_configured',
        AccountSecurityException(code: 'invalid_flow') => 'invalid_flow',
        AccountSecurityException(code: 'network') => 'network',
        AccountSecurityException(code: 'server_unavailable') =>
          'server_unavailable',
        PlatformException(code: 'CANCELED') => 'cancelled',
        _ => 'failed',
      };
      rethrow;
    } finally {
      // Fixed categories only: never URLs, flow secrets, tokens or raw errors.
      analytics.track(AnalyticsEvent.authSocialStage, {
        'stage': stage,
        'outcome': outcome,
        'elapsed_ms': timer.elapsedMilliseconds,
      });
    }
  }

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
      final error = data is Map ? data['error'] : null;
      final code = error is Map ? error['code'] : null;
      throw AccountSecurityException(
        code is String
            ? code
            : e.response != null
            ? 'server_unavailable'
            : 'network',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) {
    final stage = switch (path) {
      '/auth/social/google/start' => 'google_start',
      '/auth/social/apple/start' => 'apple_start',
      '/auth/social/complete' => 'complete',
      '/auth/social/link' => 'link',
      _ => null,
    };
    return stage == null
        ? _call('POST', path, body ?? {})
        : _observe(stage, () => _call('POST', path, body ?? {}));
  }

  @override
  Future<Map<String, dynamic>> profile() => _call('GET', '/me', null);
  @override
  Future<Map<String, dynamic>> connections() =>
      _call('GET', '/auth/connections', null);
  @override
  Future<Map<String, dynamic>> authorize(String provider) async {
    final flow = await request('/auth/social/$provider/start');
    final url = flow['authorization_url'];
    final id = flow['flow_id'];
    final secret = flow['secret'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        id is! String ||
        id.isEmpty ||
        secret is! String ||
        secret.isEmpty) {
      throw const AccountSecurityException('invalid_flow');
    }
    return _observe('browser_return', () async {
      final result = await _authenticate(
        url: url as String,
        callbackUrlScheme: 'dco-auth',
      );
      final returned = Uri.parse(result);
      if (returned.scheme != 'dco-auth' ||
          returned.host != 'callback' ||
          returned.queryParameters['flow_id'] != flow['flow_id']) {
        throw const AccountSecurityException('invalid_flow');
      }
      return {'flow_id': id, 'secret': secret};
    });
  }
}

import 'package:flutter/foundation.dart';

/// Runtime config from `--dart-define`. Never put JWT signing keys here.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.jwtOwnerAud,
    required this.mockAuth,
    required this.analyticsEnabled,
  });

  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080/v1',
    );
    const jwtOwnerAud = String.fromEnvironment(
      'JWT_OWNER_AUD',
      defaultValue: 'dco-owner',
    );
    const mockFlag = bool.fromEnvironment('DCO_MOCK_AUTH', defaultValue: true);
    const analyticsFlag = bool.fromEnvironment(
      'DCO_ANALYTICS',
      defaultValue: true,
    );
    validateApiBaseUrl(apiBaseUrl, releaseMode: kReleaseMode);
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      jwtOwnerAud: jwtOwnerAud,
      mockAuth: kReleaseMode ? false : mockFlag,
      analyticsEnabled: analyticsFlag,
    );
  }

  final String apiBaseUrl;
  final String jwtOwnerAud;

  /// Debug-only stand-in until the API exists. Forced off in release.
  final bool mockAuth;

  /// Google Analytics opt-out (`--dart-define=DCO_ANALYTICS=false`).
  final bool analyticsEnabled;
}

/// Release builds fail closed instead of sending credentials over cleartext.
void validateApiBaseUrl(String value, {required bool releaseMode}) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
      uri.hasQuery || uri.hasFragment ||
      (uri.scheme != 'https' && (releaseMode || uri.scheme != 'http'))) {
    throw StateError('API_BASE_URL must be a valid HTTPS API URL in release builds');
  }
}

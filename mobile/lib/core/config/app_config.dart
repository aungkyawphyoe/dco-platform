import 'package:flutter/foundation.dart';

/// Runtime config from `--dart-define`. Never put JWT signing keys here.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.jwtOwnerAud,
    required this.mockAuth,
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
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      jwtOwnerAud: jwtOwnerAud,
      mockAuth: kReleaseMode ? false : mockFlag,
    );
  }

  final String apiBaseUrl;
  final String jwtOwnerAud;

  /// Debug-only stand-in until the API exists. Forced off in release.
  final bool mockAuth;
}

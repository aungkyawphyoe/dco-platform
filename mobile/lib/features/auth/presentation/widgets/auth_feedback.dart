import '../../domain/auth_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/api_error_localizer.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/repositories/account_security_repository.dart';

/// Localized, user-facing message for an auth or account-security failure.
/// The server's raw message is never surfaced.
String authFeedback(BuildContext context, Object error) {
  final strings = AppLocalizations.of(context)!;
  if (error is PlatformException && error.code == 'CANCELED') return '';
  final code = switch (error) {
    AuthFailure() => error.code,
    AccountSecurityException() => error.code,
    _ => null,
  };
  return localizedApiError(strings, code);
}

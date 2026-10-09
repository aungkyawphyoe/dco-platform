import '../../domain/auth_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/repositories/account_security_repository.dart';

String authFeedback(BuildContext context, Object error) {
  final s = AppLocalizations.of(context)!;
  final code = switch (error) {
    AccountSecurityException() => error.code,
    InvalidCredentialsFailure() => 'invalid_credentials',
    EmailTakenFailure() => 'email_taken',
    NetworkAuthFailure() => 'network',
    RateLimitedFailure() => 'rate_limited',
    SessionExpiredFailure() => 'unauthorized',
    _ => '',
  };
  return switch (code) {
    'invalid_credentials' => s.authInvalidCredentials,
    'invalid_code' => s.authCodeInvalid,
    'rate_limited' => s.authRateLimited,
    'provider_not_configured' || 'auth_not_configured' => s.authNotConfigured,
    'email_taken' ||
    'account_link_required' ||
    'identity_in_use' => s.authEmailTaken,
    'unauthorized' || 'reauth_required' => s.authRecentLogin,
    'network' => s.authNetworkError,
    'delivery_failed' => s.authDeliveryError,
    _ =>
      error is PlatformException && error.code == 'CANCELED'
          ? ''
          : s.authGenericError,
  };
}

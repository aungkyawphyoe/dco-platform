import '../../../../core/network/api_error.dart';
import '../../domain/auth_failure.dart';
import '../../domain/entities/session.dart';

abstract class AuthRemoteDataSource {
  Future<Session> login({
    required String email,
    required String password,
    String? surface,
  });
  Future<Session> signup({
    required String email,
    required String password,
    String? displayName,
  });
  Future<Session> refresh({required String refreshToken});
  Future<void> logout();
  Future<void> forgotPassword({required String email});
  Future<void> resetPassword({required String token, required String password});
  Future<void> resendVerification();
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

AuthFailure mapStatusToAuthFailure(int? status, String message) {
  return switch (status) {
    401 => InvalidCredentialsFailure(message),
    403 => switch (message) {
      'password_change_required' => PasswordChangeRequiredFailure(message),
      'portal_access_restricted' => PortalAccessRestrictedFailure(message),
      'fleet_access_required' => FleetAccessRequiredFailure(message),
      _ => ForbiddenFailure(message),
    },
    409 => EmailTakenFailure(message),
    429 => RateLimitedFailure(message),
    503 => ServiceUnavailableFailure(message),
    null => NetworkAuthFailure(message),
    _ => UnknownAuthFailure(message),
  };
}

/// Preserve the backend error code so the UI can show the right localized
/// message instead of falling back to a generic one. Status is only used as a
/// fallback when the server did not send a code.
AuthFailure authFailureFromApiError(ApiError error) {
  return switch (error.code) {
    'network' => NetworkAuthFailure(error.message),
    'invalid_credentials' => InvalidCredentialsFailure(error.message),
    'email_taken' => EmailTakenFailure(error.message),
    'rate_limited' => RateLimitedFailure(error.message),
    'unauthorized' ||
    'unauthenticated' ||
    'invalid_refresh' ||
    'reauth_required' => SessionExpiredFailure(error.message),
    'password_change_required' => PasswordChangeRequiredFailure(error.message),
    'portal_access_restricted' => PortalAccessRestrictedFailure(error.message),
    'fleet_access_required' => FleetAccessRequiredFailure(error.message),
    'forbidden' => ForbiddenFailure(error.message),
    _ => _fromStatusOrCode(error),
  };
}

AuthFailure _fromStatusOrCode(ApiError error) {
  if (error.statusCode != null && error.statusCode! >= 500) {
    return ServiceUnavailableFailure(error.message);
  }
  if (error.statusCode == null || error.code == 'unknown') {
    return NetworkAuthFailure(error.message);
  }
  return ApiAuthFailure(error.code, error.message);
}

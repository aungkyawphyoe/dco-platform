sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  /// Stable code used to pick a localized message. This is the backend error
  /// code when one is available, otherwise a client-side category.
  String get code;
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    super.message = 'Email or password is incorrect',
  ]);

  @override
  String get code => 'invalid_credentials';
}

class EmailTakenFailure extends AuthFailure {
  const EmailTakenFailure([super.message = 'That email is already registered']);

  @override
  String get code => 'email_taken';
}

class NetworkAuthFailure extends AuthFailure {
  const NetworkAuthFailure([
    super.message = 'Check your connection and try again',
  ]);

  @override
  String get code => 'network';
}

class RateLimitedFailure extends AuthFailure {
  const RateLimitedFailure([
    super.message = 'Too many attempts. Try again shortly',
  ]);

  @override
  String get code => 'rate_limited';
}

class ServiceUnavailableFailure extends AuthFailure {
  const ServiceUnavailableFailure([
    super.message = 'Service temporarily unavailable. Try again shortly',
  ]);

  @override
  String get code => 'server_unavailable';
}

class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([
    super.message = 'Session expired. Sign in again',
  ]);

  @override
  String get code => 'unauthorized';
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure([super.message = 'Something went wrong']);

  @override
  String get code => 'unknown';
}

class PasswordChangeRequiredFailure extends AuthFailure {
  const PasswordChangeRequiredFailure([
    super.message = 'Temporary password must be changed',
  ]);

  @override
  String get code => 'password_change_required';
}

class PortalAccessRestrictedFailure extends AuthFailure {
  const PortalAccessRestrictedFailure([
    super.message = 'Drivers do not use the Fleet Portal',
  ]);

  @override
  String get code => 'portal_access_restricted';
}

class FleetAccessRequiredFailure extends AuthFailure {
  const FleetAccessRequiredFailure([
    super.message = 'An active Enterprise organization membership is required',
  ]);

  @override
  String get code => 'fleet_access_required';
}

class ForbiddenFailure extends AuthFailure {
  const ForbiddenFailure([super.message = 'Access denied']);

  @override
  String get code => 'forbidden';
}

/// A backend auth error that does not need its own failure type. Keeping the
/// server code lets the presentation layer localize it without showing the
/// raw server message.
class ApiAuthFailure extends AuthFailure {
  const ApiAuthFailure(this.code, [super.message = 'Something went wrong']);

  @override
  final String code;

  @override
  String toString() => 'ApiAuthFailure($code)';
}

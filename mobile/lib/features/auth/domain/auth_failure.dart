sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([super.message = 'Email or password is incorrect']);
}

class EmailTakenFailure extends AuthFailure {
  const EmailTakenFailure([super.message = 'That email is already registered']);
}

class NetworkAuthFailure extends AuthFailure {
  const NetworkAuthFailure([super.message = 'Check your connection and try again']);
}

class RateLimitedFailure extends AuthFailure {
  const RateLimitedFailure([super.message = 'Too many attempts. Try again shortly']);
}

class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([super.message = 'Session expired. Sign in again']);
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure([super.message = 'Something went wrong']);
}

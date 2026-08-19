import '../../domain/auth_failure.dart';
import '../../domain/entities/session.dart';

abstract class AuthRemoteDataSource {
  Future<Session> login({required String email, required String password});
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
}

AuthFailure mapStatusToAuthFailure(int? status, String message) {
  return switch (status) {
    401 => InvalidCredentialsFailure(message),
    409 => EmailTakenFailure(message),
    429 => RateLimitedFailure(message),
    null => NetworkAuthFailure(message),
    _ => UnknownAuthFailure(message),
  };
}

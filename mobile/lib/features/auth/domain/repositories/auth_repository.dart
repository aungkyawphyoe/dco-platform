import '../entities/session.dart';

abstract class AuthRepository {
  Future<Session?> restoreSession();
  Future<Session> signIn({required String email, required String password});
  Future<Session> signUp({
    required String email,
    required String password,
    String? displayName,
  });
  Future<void> signOut();
  Future<void> requestPasswordReset({required String email});
  Future<void> resetPassword({required String token, required String password});
  Future<void> resendVerification();
}

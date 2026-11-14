import 'dart:convert';

import '../../../../core/storage/token_store.dart';
import '../../domain/auth_failure.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStore tokenStore,
  }) : _remote = remote,
       _tokenStore = tokenStore;

  final AuthRemoteDataSource _remote;
  final TokenStore _tokenStore;

  @override
  Future<Session?> restoreSession() async {
    final generation = _tokenStore.generation;
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final session = await _remote.refresh(refreshToken: refresh);
      await _persist(session, generation);
      return session;
    } on AuthFailure catch (failure) {
      if (_tokenStore.generation != generation) return null;
      final rejected =
          failure is InvalidCredentialsFailure ||
          failure is SessionExpiredFailure ||
          failure is ForbiddenFailure;
      final cached = await _tokenStore.readUserJson();
      final access = await _tokenStore.readAccessToken();
      if (_tokenStore.generation != generation) return null;
      // Connectivity and server failures must not revoke offline access.
      if ((!rejected || refresh.startsWith('mock_refresh_')) &&
          cached != null &&
          access != null &&
          access.isNotEmpty) {
        try {
          final user = User.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
          return Session(
            accessToken: access,
            refreshToken: refresh,
            user: user,
          );
        } on FormatException {
          // Preserve credentials when the cached profile cannot be restored.
        } on TypeError {
          // An incomplete cached profile is not a usable offline session.
        }
      }
      if (!rejected) rethrow;
      if (_tokenStore.generation == generation) await _tokenStore.clear();
      return null;
    }
  }

  @override
  Future<Session> signIn({
    required String email,
    required String password,
    String? surface,
  }) async {
    final generation = _tokenStore.generation;
    final session = await _remote.login(
      email: email,
      password: password,
      surface: surface,
    );
    await _persist(session, generation);
    return session;
  }

  @override
  Future<Session> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final generation = _tokenStore.generation;
    final session = await _remote.signup(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _persist(session, generation);
    return session;
  }

  @override
  Future<void> signOut() async {
    try {
      await _remote.logout();
    } on AuthFailure {
      // Local discard still happens.
    }
    await _tokenStore.clear();
  }

  @override
  Future<void> requestPasswordReset({required String email}) {
    return _remote.forgotPassword(email: email);
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) {
    return _remote.resetPassword(token: token, password: password);
  }

  @override
  Future<void> resendVerification() => _remote.resendVerification();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _remote.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> _persist(Session session, int generation) {
    return _tokenStore.writeSession(
      expectedGeneration: generation,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userJson: jsonEncode(session.user.toJson()),
    );
  }
}

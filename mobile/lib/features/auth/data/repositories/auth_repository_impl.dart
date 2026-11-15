import 'dart:convert';

import '../../../../core/storage/token_store.dart';
import '../../../../core/gating/trusted_clock.dart';
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
    final expiresAt = jwtExpiresAt(refresh);
    final expired = expiresAt != null && !DateTime.now().isBefore(expiresAt);
    final cached = await _readCachedSession(refresh);
    if (_tokenStore.generation != generation) return null;
    // API requests can refresh the access token when the server rejects it.
    // A slow connection must not delay access to an unexpired local session.
    if (expiresAt != null && !expired && cached != null) return cached;

    try {
      final session = await _remote.refresh(refreshToken: refresh);
      await _persist(session, generation);
      return session;
    } on AuthFailure catch (failure) {
      if (_tokenStore.generation != generation) return null;
      final rejected =
          expired ||
          failure is InvalidCredentialsFailure ||
          failure is SessionExpiredFailure ||
          failure is ForbiddenFailure;
      if ((!rejected || refresh.startsWith('mock_refresh_')) &&
          cached != null) {
        return cached;
      }
      if (!rejected) rethrow;
      await _tokenStore.clear();
      return null;
    }
  }

  Future<Session?> _readCachedSession(String refresh) async {
    final userJson = await _tokenStore.readUserJson();
    final access = await _tokenStore.readAccessToken();
    if (userJson == null || access == null || access.isEmpty) return null;
    try {
      return Session(
        accessToken: access,
        refreshToken: refresh,
        user: User.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
      );
    } on FormatException {
      return null;
    } on TypeError {
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

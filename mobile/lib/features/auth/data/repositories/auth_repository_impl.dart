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
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final session = await _remote.refresh(refreshToken: refresh);
      await _persist(session);
      return session;
    } on AuthFailure {
      final cached = await _tokenStore.readUserJson();
      if (refresh.startsWith('mock_refresh_') && cached != null) {
        final user = User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        return Session(
          accessToken: await _tokenStore.readAccessToken() ?? 'mock_access',
          refreshToken: refresh,
          user: user,
        );
      }
      await _tokenStore.clear();
      return null;
    }
  }

  @override
  Future<Session> signIn({required String email, required String password}) async {
    final session = await _remote.login(email: email, password: password);
    await _persist(session);
    return session;
  }

  @override
  Future<Session> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final session = await _remote.signup(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _persist(session);
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
  Future<void> resetPassword({required String token, required String password}) {
    return _remote.resetPassword(token: token, password: password);
  }

  @override
  Future<void> resendVerification() => _remote.resendVerification();

  Future<void> _persist(Session session) {
    return _tokenStore.writeSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userJson: jsonEncode(session.user.toJson()),
    );
  }
}

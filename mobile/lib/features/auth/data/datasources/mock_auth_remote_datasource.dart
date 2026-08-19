import 'package:uuid/uuid.dart';

import '../../domain/auth_failure.dart';
import '../../domain/entities/session.dart';
import 'auth_remote_datasource.dart';

/// Debug stand-in so the shell can be exercised before the API exists.
class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  MockAuthRemoteDataSource();

  static const _uuid = Uuid();
  final Map<String, _MockAccount> _accounts = {};
  @override
  Future<Session> login({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final key = email.trim().toLowerCase();
    final existing = _accounts[key];
    if (existing == null) {
      return _issue(email: key, password: password, verified: true);
    }
    if (existing.password != password) {
      throw const InvalidCredentialsFailure();
    }
    return _sessionFor(existing);
  }

  @override
  Future<Session> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const EmailTakenFailure();
    }
    return _issue(email: key, password: password, displayName: displayName, verified: false);
  }

  @override
  Future<Session> refresh({required String refreshToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final match = _accounts.values.cast<_MockAccount?>().firstWhere(
      (account) => account?.refreshToken == refreshToken,
      orElse: () => null,
    );
    if (match == null) {
      throw const SessionExpiredFailure();
    }
    return _sessionFor(match);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({required String token, required String password}) async {
    if (token.isEmpty || password.length < 8) {
      throw const UnknownAuthFailure('Reset link expired or already used');
    }
  }

  @override
  Future<void> resendVerification() async {}

  Session _issue({
    required String email,
    required String password,
    String? displayName,
    required bool verified,
  }) {
    final account = _MockAccount(
      user: User(
        id: _uuid.v4(),
        email: email,
        displayName: displayName,
        role: 'owner',
        plan: 'free',
        status: 'active',
        emailVerified: verified,
      ),
      password: password,
      refreshToken: 'mock_refresh_${_uuid.v4()}',
    );
    _accounts[email] = account;
    return _sessionFor(account);
  }

  Session _sessionFor(_MockAccount account) {
    return Session(
      accessToken: 'mock_access_${account.user.id}',
      refreshToken: account.refreshToken,
      expiresIn: 900,
      user: account.user,
    );
  }
}

class _MockAccount {
  _MockAccount({
    required this.user,
    required this.password,
    required this.refreshToken,
  });

  final User user;
  final String password;
  String refreshToken;
}

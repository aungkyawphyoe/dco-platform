import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'dco.access_token';
  static const _refreshKey = 'dco.refresh_token';
  static const _userKey = 'dco.user_json';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<String?> readUserJson() => _storage.read(key: _userKey);

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _userKey, value: userJson);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}

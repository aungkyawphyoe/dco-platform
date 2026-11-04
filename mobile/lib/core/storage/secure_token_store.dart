import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _accessKey = 'dco.access_token';
  static const _refreshKey = 'dco.refresh_token';
  static const _userKey = 'dco.user_json';

  final FlutterSecureStorage _storage;

  int _generation = 0;
  Future<void> _pending = Future.value();
  @override
  int get generation => _generation;

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<String?> readAccessToken() =>
      _serialized(() => _storage.read(key: _accessKey));
  @override
  Future<String?> readRefreshToken() =>
      _serialized(() => _storage.read(key: _refreshKey));
  @override
  Future<String?> readUserJson() =>
      _serialized(() => _storage.read(key: _userKey));

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
    int? expectedGeneration,
  }) {
    final expected = expectedGeneration ?? generation;
    return _serialized(() async {
      if (expected != generation) throw StateError('Account changed');
      await _storage.write(key: _accessKey, value: accessToken);
      await _storage.write(key: _refreshKey, value: refreshToken);
      await _storage.write(key: _userKey, value: userJson);
    });
  }

  @override
  Future<void> clear() {
    _generation++;
    return _serialized(() async {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _userKey);
    });
  }
}

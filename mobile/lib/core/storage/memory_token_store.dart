import 'token_store.dart';

class MemoryTokenStore implements TokenStore {
  int _generation = 0;
  @override
  int get generation => _generation;

  String? _access;
  String? _refresh;
  String? _userJson;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<String?> readUserJson() async => _userJson;

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null && expectedGeneration != generation) {
      throw StateError('Account changed');
    }
    _access = accessToken;
    _refresh = refreshToken;
    _userJson = userJson;
  }

  @override
  Future<void> clear() async {
    _generation++;
    _access = null;
    _refresh = null;
    _userJson = null;
  }
}

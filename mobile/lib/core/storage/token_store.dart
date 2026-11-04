abstract class TokenStore {
  int get generation;
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<String?> readUserJson();
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
    int? expectedGeneration,
  });
  Future<void> clear();
}

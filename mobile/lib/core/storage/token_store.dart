abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<String?> readUserJson();
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  });
  Future<void> clear();
}

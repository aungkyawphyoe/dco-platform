/// Online account operations. Presentation never accesses the HTTP client.
abstract class AccountSecurityRepository {
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]);
  Future<Map<String, dynamic>> connections();
  Future<Map<String, dynamic>> profile();
  Future<Map<String, dynamic>> authorize(String provider);
}

class AccountSecurityException implements Exception {
  const AccountSecurityException(this.code);
  final String code;
  @override
  String toString() => code;
}

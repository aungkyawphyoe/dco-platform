import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistence for the signed license and the rollback guard
/// (`architecture/feature-gating.md` §7). Both live in Keychain /
/// Keystore — never in Drift — so a local DB editor cannot roll back
/// entitlements or the clock anchor together.
///
/// Keys are scoped per user: a different account on the same phone must
/// not inherit the previous account's license (same rule as the outbox).
abstract class LicenseStore {
  Future<String?> readLicense(String userId);

  Future<void> writeLicense(String userId, String license);

  Future<void> clearLicense(String userId);

  Future<DateTime?> readMaxSeen(String userId);

  Future<void> writeMaxSeen(String userId, DateTime time);
}

class SecureLicenseStore implements LicenseStore {
  SecureLicenseStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static String licenseKey(String userId) => 'dco.license.$userId';

  static String maxSeenKey(String userId) => 'dco.license.max_seen.$userId';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readLicense(String userId) =>
      _storage.read(key: licenseKey(userId));

  @override
  Future<void> writeLicense(String userId, String license) =>
      _storage.write(key: licenseKey(userId), value: license);

  @override
  Future<void> clearLicense(String userId) =>
      _storage.delete(key: licenseKey(userId));

  @override
  Future<DateTime?> readMaxSeen(String userId) async {
    final raw = await _storage.read(key: maxSeenKey(userId));
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<void> writeMaxSeen(String userId, DateTime time) =>
      _storage.write(key: maxSeenKey(userId), value: time.toUtc().toIso8601String());
}

/// In-memory store for widget/unit tests — mirrors `MemoryTokenStore`.
/// Never used in production builds.
class MemoryLicenseStore implements LicenseStore {
  final _licenses = <String, String>{};
  final _maxSeen = <String, DateTime>{};

  @override
  Future<String?> readLicense(String userId) async => _licenses[userId];

  @override
  Future<void> writeLicense(String userId, String license) async {
    _licenses[userId] = license;
  }

  @override
  Future<void> clearLicense(String userId) async {
    _licenses.remove(userId);
  }

  @override
  Future<DateTime?> readMaxSeen(String userId) async => _maxSeen[userId];

  @override
  Future<void> writeMaxSeen(String userId, DateTime time) async {
    _maxSeen[userId] = time;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'feature_gate.dart';
import 'license_api.dart';
import 'license_models.dart';
import 'license_store.dart';
import 'license_verifier.dart';
import 'trusted_clock.dart';

final licenseStoreProvider = Provider<LicenseStore>((ref) {
  return SecureLicenseStore();
});

final licenseApiProvider = Provider<LicenseApi>((ref) {
  return LicenseApi(ref.watch(dioProvider));
});

/// Bundled `kid` → Ed25519 public keyring (`assets/license_keys.json`).
/// Ships public keys only; mint a pair with `npm run license:key` in
/// `backend/` and paste the keyring entry here (§5.2 rotation: keyring
/// is a list, old kids stay trusted across releases).
final licenseKeyringProvider =
    FutureProvider<List<LicenseKeyringEntry>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/license_keys.json');
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) LicenseKeyringEntry.fromJson(item),
    ];
  } catch (_) {
    return const [];
  }
});

/// Hydrates the cached license from secure storage, verifies it, and
/// refreshes from the server when stale (decision 14: startup never
/// awaits the network — the gate works from cache first).
final licenseControllerProvider =
    AsyncNotifierProvider<LicenseController, EntitlementClaims>(
  LicenseController.new,
);

class LicenseController extends AsyncNotifier<EntitlementClaims> {
  String? _userId;
  TrustedClock? _clock;
  LicenseVerifier? _verifier;

  @override
  Future<EntitlementClaims> build() async {
    final userId = ref.watch(currentUserIdProvider);
    _userId = userId;
    if (userId == null) return EntitlementClaims.free;

    final store = ref.read(licenseStoreProvider);
    final keyring = await ref.read(licenseKeyringProvider.future);
    final clock = TrustedClock(store: store, userId: userId);
    final verifier = LicenseVerifier(keyring: keyring, trustedNow: clock.now);
    _clock = clock;
    _verifier = verifier;

    EntitlementClaims? claims;
    final stored = await store.readLicense(userId);
    if (stored != null) claims = await verifier.verify(stored);
    final hydrated = claims ?? EntitlementClaims.free;

    // Fire-and-forget: stale refresh runs after hydration settles; the
    // cached (or Free) claims gate the UI immediately. Free fallback
    // claims are issued at the epoch → always stale → a signed-in user
    // fetches the real license; startup never blocks on the network
    // (decision 14).
    scheduleMicrotask(refreshIfStale);
    return hydrated;
  }

  /// Foreground / post-auth trigger: refresh only when stale — issued
  /// >24h ago or expiring within 48h (§5.3). Never blocks the caller on
  /// startup; safe to call at any time.
  Future<void> refreshIfStale({bool force = false}) async {
    final claims = await future;
    if (force || await _isStale(claims)) await _fetchAndStore();
  }

  static const staleAfter = Duration(hours: 24);
  static const expiryHorizon = Duration(hours: 48);

  Future<bool> _isStale(EntitlementClaims claims) async {
    final clock = _clock;
    if (clock == null) return false;
    final now = await clock.now();
    if (now.difference(claims.issuedAt) > staleAfter) return true;
    if (claims.expiresAt.difference(now) < expiryHorizon) return true;
    return false;
  }

  Future<void> _fetchAndStore() async {
    final userId = _userId;
    final clock = _clock;
    final verifier = _verifier;
    if (userId == null || clock == null || verifier == null) return;
    if (userId != ref.read(currentUserIdProvider)) return;
    try {
      final jwt = await ref.read(licenseApiProvider).fetch();
      final verified = await verifier.verify(jwt);
      if (verified == null) return;
      await ref.read(licenseStoreProvider).writeLicense(userId, jwt);
      await clock.observe(verified.issuedAt);
      if (userId != ref.read(currentUserIdProvider)) return;
      state = AsyncData(verified);
      // A fresher license can lift a plan cap — let parked outbox rows
      // try again (§9, "requeue after upgrade").
      await ref.read(syncEngineProvider).requeueParked(userId);
    } catch (_) {
      // Offline or endpoint unavailable: the cached license stands.
    }
  }
}

/// Live count of active (non-archived) owned vehicles — same semantics
/// as backend `countActiveVehicles` and `_countGarage`.
final activeVehicleCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);
  final db = ref.watch(appDatabaseProvider);
  final count = db.vehicleRecords.id.count();
  final query = db.selectOnly(db.vehicleRecords)
    ..addColumns([count])
    ..where(
      db.vehicleRecords.userId.equals(userId) &
          db.vehicleRecords.archived.equals(false),
    );
  return query.map((row) => row.read(count) ?? 0).watchSingle();
});

/// Live count of the owner's `active` shares — mirrors the server's
/// `checkShareLimits` (join on owned vehicles, status `active`).
final activeShareCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);
  final db = ref.watch(appDatabaseProvider);
  final count = db.vehicleShareRecords.id.count();
  final query = db.select(db.vehicleShareRecords).join(
    [
      innerJoin(
        db.vehicleRecords,
        db.vehicleRecords.id.equalsExp(db.vehicleShareRecords.vehicleId),
        useColumns: false,
      ),
    ],
  )
    ..where(
      db.vehicleRecords.userId.equals(userId) &
          db.vehicleShareRecords.status.equals('active'),
    )
    ..addColumns([count]);
  return query.map((row) => row.read(count) ?? 0).watchSingle();
});

/// Folding point for screens: `null` while hydrating → deny by default
/// (§8.1). Claims fall back to Free whenever verification failed.
final featureGateProvider = Provider<FeatureGateSnapshot?>((ref) {
  final license = ref.watch(licenseControllerProvider);
  if (license.isLoading) return null;
  final vehicles = ref.watch(activeVehicleCountProvider);
  final shares = ref.watch(activeShareCountProvider);
  if (!vehicles.hasValue || !shares.hasValue) return null;
  return FeatureGateSnapshot(
    claims: license.valueOrNull ?? EntitlementClaims.free,
    vehicleCount: vehicles.valueOrNull ?? 0,
    activeShareCount: shares.valueOrNull ?? 0,
  );
});

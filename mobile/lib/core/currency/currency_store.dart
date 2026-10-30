import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

const operationalCurrencies = {'MMK', 'USD', 'THB', 'CNY'};

/// Authoritative state cached in the account's record database. Shared vehicles
/// have their own scope; a viewer's personal preference is never their currency.
class CurrencyStore {
  CurrencyStore(this.db);
  final AppDatabase db;
  String key(String userId, String? vehicleId) =>
      'currency:$userId:${vehicleId ?? "scope"}';

  Future<Map<String, dynamic>?> read(String userId, {String? vehicleId}) async {
    final row = await (db.select(
      db.appMeta,
    )..where((r) => r.key.equals(key(userId, vehicleId)))).getSingleOrNull();
    return row?.value == null
        ? null
        : jsonDecode(row!.value!) as Map<String, dynamic>;
  }

  Stream<Map<String, dynamic>?> watch(String userId, {String? vehicleId}) {
    return (db.select(db.appMeta)
          ..where((r) => r.key.equals(key(userId, vehicleId))))
        .watchSingleOrNull()
        .map(
          (row) => row?.value == null
              ? null
              : jsonDecode(row!.value!) as Map<String, dynamic>,
        );
  }

  Future<void> save(
    String userId,
    Map<String, dynamic> state, {
    String? vehicleId,
  }) async {
    if (state['currency'] != null &&
        !operationalCurrencies.contains(state['currency'])) {
      throw const FormatException('Unsupported currency');
    }
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(
            key: key(userId, vehicleId),
            value: Value(jsonEncode(state)),
          ),
          onConflict: DoUpdate(
            (_) => AppMetaCompanion(value: Value(jsonEncode(state))),
            target: [db.appMeta.key],
          ),
        );
  }

  /// Validate the currency captured by the form; never silently replace it.
  Future<String> validateCreation(
    String userId,
    String intended, {
    String? vehicleId,
  }) async {
    if (!operationalCurrencies.contains(intended)) {
      throw StateError('Unsupported currency');
    }
    var state = await read(userId, vehicleId: vehicleId);
    final account = vehicleId == null ? state : await read(userId);
    if (state == null && vehicleId != null) {
      final vehicle = await (db.select(
        db.vehicleRecords,
      )..where((r) => r.id.equals(vehicleId))).getSingleOrNull();
      // A newly created offline owned vehicle inherits its owner's cached scope.
      // A shared vehicle must have its owner's state fetched explicitly.
      if (vehicle?.userId == userId ||
          (vehicle != null && account?['organization_id'] != null)) {
        state = account;
      }
    }
    if (state == null && account?['enabled'] == true) {
      throw StateError('Sync this vehicle currency before recording costs.');
    }
    final active = state?['enabled'] == true;
    if (active && state?['currency'] == null) {
      throw StateError('Select a currency before recording costs.');
    }
    if (active && state?['review_required'] == true) {
      throw StateError('Currency history requires review.');
    }
    final expected = active ? state!['currency'] : 'MMK';
    if (intended != expected) {
      throw StateError('Currency changed. Re-enter the amount in $expected.');
    }
    return intended;
  }

  Future<void> markLocalCreation(String userId, {String? vehicleId}) async {
    if (vehicleId != null) {
      final vehicle = await (db.select(
        db.vehicleRecords,
      )..where((r) => r.id.equals(vehicleId))).getSingleOrNull();
      final account = await read(userId);
      if (vehicle?.userId == userId || account?['organization_id'] != null) {
        await markLocalCreation(userId);
      }
    }
    final name = '${key(userId, vehicleId)}:local_lock';
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(key: name, value: const Value('true')),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<bool> hasLocalLock(String userId, {String? vehicleId}) async =>
      await (db.select(
            db.appMeta,
          )..where((r) => r.key.equals('${key(userId, vehicleId)}:local_lock')))
          .getSingleOrNull() !=
      null;
}

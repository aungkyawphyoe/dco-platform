import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/entities/fuel_catalog_type.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/fuel_failure.dart';
import '../../domain/fuel_validators.dart';
import '../../domain/repositories/fuel_repository.dart';
import '../mappers/fuel_mapper.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class FuelRepositoryImpl implements FuelRepository {
  FuelRepositoryImpl({
    required AppDatabase db,
    required OutboxWriter outbox,
    SyncEngine syncEngine = const SyncEngine(),
    Uuid uuid = const Uuid(),
  }) : _db = db,
       _outbox = outbox,
       _sync = syncEngine,
       _uuid = uuid;

  final AppDatabase _db;
  final OutboxWriter _outbox;
  final SyncEngine _sync;
  final Uuid _uuid;

  static const _defaultLiquid = [
    (name: 'Petrol', unit: 'L'),
    (name: 'Diesel', unit: 'L'),
  ];
  static const _defaultElectric = [(name: 'Electricity', unit: 'kWh')];

  @override
  Stream<List<FuelCatalogType>> watchFuelTypes(String userId, {FuelCatalogKind? kind}) {
    final query = _db.select(_db.fuelTypeRecords)..where((row) => row.userId.equals(userId));
    if (kind != null) {
      query.where((row) => row.kind.equals(kind.storage));
    }
    query.orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.watch().map((rows) => rows.map(fuelCatalogTypeFromDrift).toList());
  }

  @override
  Future<FuelCatalogType?> getFuelType(String id) async {
    final row = await (_db.select(_db.fuelTypeRecords)..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : fuelCatalogTypeFromDrift(row);
  }

  @override
  Future<void> ensureDefaultFuelTypes(String userId) async {
    final existing = await (_db.select(_db.fuelTypeRecords)..where((row) => row.userId.equals(userId))).get();
    final hasLiquid = existing.any((row) => row.kind == FuelCatalogKind.liquid.storage);
    final hasElectric = existing.any((row) => row.kind == FuelCatalogKind.electric.storage);
    if (hasLiquid && hasElectric) return;

    if (!hasLiquid) {
      for (final item in _defaultLiquid) {
        await addFuelType(
          userId: userId,
          draft: FuelCatalogTypeDraft(
            name: item.name,
            kind: FuelCatalogKind.liquid,
            unit: item.unit,
          ),
        );
      }
    }
    if (!hasElectric) {
      for (final item in _defaultElectric) {
        await addFuelType(
          userId: userId,
          draft: FuelCatalogTypeDraft(
            name: item.name,
            kind: FuelCatalogKind.electric,
            unit: item.unit,
          ),
        );
      }
    }
  }

  @override
  Future<FuelCatalogType> addFuelType({
    required String userId,
    required FuelCatalogTypeDraft draft,
  }) async {
    _assertTypeDraft(draft);
    await _assertUniqueTypeName(userId: userId, name: draft.name);

    final now = DateTime.now().toUtc();
    final type = FuelCatalogType(
      id: _uuid.v4(),
      userId: userId,
      name: draft.name.trim(),
      kind: draft.kind,
      unit: draft.unit,
      updatedAt: now,
      createdAt: now,
    );

    await _db.transaction(() async {
      await _db.into(_db.fuelTypeRecords).insert(fuelCatalogTypeToCompanion(type));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.fuelType,
        entityId: type.id,
        op: OutboxOp.upsert,
        payload: type.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return type;
  }

  @override
  Future<FuelCatalogType> updateFuelType({
    required String userId,
    required String fuelTypeId,
    required FuelCatalogTypeDraft draft,
  }) async {
    _assertTypeDraft(draft);
    final existing = await getFuelType(fuelTypeId);
    if (existing == null || existing.userId != userId) {
      throw const FuelTypeNotFoundFailure();
    }
    await _assertUniqueTypeName(userId: userId, name: draft.name, excludingId: fuelTypeId);

    final updated = FuelCatalogType(
      id: existing.id,
      userId: existing.userId,
      name: draft.name.trim(),
      kind: draft.kind,
      unit: draft.unit,
      updatedAt: DateTime.now().toUtc(),
      createdAt: existing.createdAt,
    );

    await _db.transaction(() async {
      await (_db.update(_db.fuelTypeRecords)..where((row) => row.id.equals(fuelTypeId))).write(
        fuelCatalogTypeToCompanion(updated),
      );
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.fuelType,
        entityId: updated.id,
        op: OutboxOp.upsert,
        payload: updated.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return updated;
  }

  @override
  Stream<List<FuelLog>> watchLogs({
    required String vehicleId,
    required FuelLogKind kind,
  }) {
    final query = _db.select(_db.fuelLogRecords)
      ..where((row) => row.vehicleId.equals(vehicleId) & row.kind.equals(kind.storage))
      ..orderBy([(row) => OrderingTerm.desc(row.loggedOn), (row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map((rows) => rows.map(fuelLogFromDrift).toList());
  }

  @override
  Future<FuelLog?> getLog(String id) async {
    final row = await (_db.select(_db.fuelLogRecords)..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : fuelLogFromDrift(row);
  }

  @override
  Future<FuelLog> addLog({
    required String userId,
    required String vehicleId,
    required FuelLogKind kind,
    required FuelLogDraft draft,
  }) async {
    final catalog = await _requireMatchingType(
      userId: userId,
      fuelTypeId: draft.fuelTypeId,
      kind: kind,
    );
    _assertLogDraft(draft);

    final now = DateTime.now().toUtc();
    final log = FuelLog(
      id: _uuid.v4(),
      userId: userId,
      vehicleId: vehicleId,
      kind: kind,
      fuelTypeId: catalog.id,
      fuelTypeName: catalog.name,
      unit: catalog.unit,
      loggedOn: _dateOnly(draft.loggedOn),
      amount: draft.amount,
      cost: draft.cost,
      updatedAt: now,
      createdAt: now,
    );

    await _db.transaction(() async {
      await _db.into(_db.fuelLogRecords).insert(fuelLogToCompanion(log));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.fuelLog,
        entityId: log.id,
        op: OutboxOp.upsert,
        payload: log.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return log;
  }

  @override
  Future<FuelLog> updateLog({
    required String userId,
    required String logId,
    required FuelLogKind kind,
    required FuelLogDraft draft,
  }) async {
    final existing = await getLog(logId);
    if (existing == null || existing.userId != userId) {
      throw const FuelLogNotFoundFailure();
    }
    if (existing.kind != kind) {
      throw const FuelTypeKindMismatchFailure();
    }
    final catalog = await _requireMatchingType(
      userId: userId,
      fuelTypeId: draft.fuelTypeId,
      kind: kind,
    );
    _assertLogDraft(draft);

    final updated = FuelLog(
      id: existing.id,
      userId: existing.userId,
      vehicleId: existing.vehicleId,
      kind: existing.kind,
      fuelTypeId: catalog.id,
      fuelTypeName: catalog.name,
      unit: catalog.unit,
      loggedOn: _dateOnly(draft.loggedOn),
      amount: draft.amount,
      cost: draft.cost,
      updatedAt: DateTime.now().toUtc(),
      createdAt: existing.createdAt,
    );

    await _db.transaction(() async {
      await (_db.update(_db.fuelLogRecords)..where((row) => row.id.equals(logId))).write(
        fuelLogToCompanion(updated),
      );
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.fuelLog,
        entityId: updated.id,
        op: OutboxOp.upsert,
        payload: updated.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return updated;
  }

  void _assertTypeDraft(FuelCatalogTypeDraft draft) {
    final nameError = FuelTypeValidators.name(draft.name);
    if (nameError != null) throw FuelValidationFailure(nameError);
    final unitError = FuelTypeValidators.unit(draft.kind, draft.unit);
    if (unitError != null) throw FuelValidationFailure(unitError);
  }

  void _assertLogDraft(FuelLogDraft draft) {
    final dateError = FuelLogValidators.date(draft.loggedOn, now: DateTime.now());
    if (dateError != null) throw FuelValidationFailure(dateError);
    if (draft.amount <= 0 || draft.amount > FuelLogValidators.maxAmount) {
      throw const FuelValidationFailure('Enter an amount greater than 0');
    }
    if (draft.cost < 0 || draft.cost > FuelLogValidators.maxCost) {
      throw const FuelValidationFailure('Enter a valid cost');
    }
  }

  Future<void> _assertUniqueTypeName({
    required String userId,
    required String name,
    String? excludingId,
  }) async {
    final normalized = name.trim().toLowerCase();
    final rows = await (_db.select(_db.fuelTypeRecords)..where((row) => row.userId.equals(userId))).get();
    final clash = rows.any(
      (row) => row.name.trim().toLowerCase() == normalized && row.id != excludingId,
    );
    if (clash) throw const DuplicateFuelTypeNameFailure();
  }

  Future<FuelCatalogType> _requireMatchingType({
    required String userId,
    required String fuelTypeId,
    required FuelLogKind kind,
  }) async {
    final type = await getFuelType(fuelTypeId);
    if (type == null || type.userId != userId) {
      throw const FuelTypeNotFoundFailure();
    }
    if (type.kind != kind.catalogKind) {
      throw const FuelTypeKindMismatchFailure();
    }
    return type;
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
}

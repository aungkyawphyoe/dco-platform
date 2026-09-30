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
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../../../expenses/domain/entities/expense.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class FuelRepositoryImpl implements FuelRepository {
  FuelRepositoryImpl({
    required AppDatabase db,
    required OutboxWriter outbox,
    SyncEngine? syncEngine,
    Uuid uuid = const Uuid(),
    required ExpenseRepository expenseRepository,
  }) : _db = db,
        _outbox = outbox,
        _sync = syncEngine,
        _uuid = uuid,
        _expenseRepository = expenseRepository;

  final AppDatabase _db;
  final OutboxWriter _outbox;
  final SyncEngine? _sync;
  final Uuid _uuid;
  final ExpenseRepository _expenseRepository;

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
    _sync?.requestSync();
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
    _sync?.requestSync();
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
    final vehicle = await _requireVehicle(vehicleId);
    _assertOdometer(vehicle, draft);

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
      odometer: draft.odometer,
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
      await _bumpVehicleMileageIfNeeded(userId: userId, vehicle: vehicle, odometer: draft.odometer, now: now);
      // Auto-create expense for fuel cost
      await _expenseRepository.add(
        userId: userId,
        vehicleId: vehicleId,
        draft: ExpenseDraft(
          category: ExpenseCategory.fuel,
          amount: draft.cost,
          incurredOn: draft.loggedOn,
        ),
      );
    });
    _sync?.requestSync();
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
    final vehicle = await _requireVehicle(existing.vehicleId);
    _assertOdometer(vehicle, draft);

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
      odometer: draft.odometer,
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
      await _bumpVehicleMileageIfNeeded(
        userId: userId,
        vehicle: vehicle,
        odometer: draft.odometer,
        now: updated.updatedAt,
      );
      // Auto-create/update expense for fuel cost
      await _expenseRepository.add(
        userId: userId,
        vehicleId: existing.vehicleId,
        draft: ExpenseDraft(
          category: ExpenseCategory.fuel,
          amount: draft.cost,
          incurredOn: draft.loggedOn,
        ),
      );
    });
    _sync?.requestSync();
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
    if (draft.odometer != null) {
      if (draft.odometer! < 0 || draft.odometer! > FuelLogValidators.maxOdometer) {
        throw const FuelValidationFailure('Enter a valid odometer');
      }
    }
  }

  Future<VehicleRecord> _requireVehicle(String vehicleId) async {
    final vehicle = await (_db.select(_db.vehicleRecords)..where((row) => row.id.equals(vehicleId))).getSingleOrNull();
    if (vehicle == null) throw const FuelLogNotFoundFailure();
    return vehicle;
  }

  void _assertOdometer(VehicleRecord vehicle, FuelLogDraft draft) {
    if (draft.odometer == null) return;
    if (draft.odometer! < vehicle.mileage) {
      throw const FuelValidationFailure('Odometer cannot be below vehicle mileage');
    }
  }

  Future<void> _bumpVehicleMileageIfNeeded({
    required String userId,
    required VehicleRecord vehicle,
    required double? odometer,
    required DateTime now,
  }) async {
    if (odometer == null || odometer <= vehicle.mileage) return;
    await (_db.update(_db.vehicleRecords)..where((row) => row.id.equals(vehicle.id))).write(
      VehicleRecordsCompanion(
        mileage: Value(odometer),
        updatedAt: Value(now),
      ),
    );
    await _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.vehicle,
      entityId: vehicle.id,
      op: OutboxOp.upsert,
      payload: {'id': vehicle.id, 'mileage': odometer},
    );
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

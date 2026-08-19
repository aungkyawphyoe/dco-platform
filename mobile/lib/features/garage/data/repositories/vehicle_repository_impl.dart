import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/vehicle_failure.dart';
import '../mappers/vehicle_mapper.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class VehicleRepositoryImpl implements VehicleRepository {
  VehicleRepositoryImpl({
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

  @override
  Stream<List<Vehicle>> watchGarage(String userId) {
    final query = _db.select(_db.vehicleRecords)
      ..where((row) => row.userId.equals(userId) & row.archived.equals(false))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map((rows) => rows.map(vehicleFromDrift).toList());
  }

  @override
  Stream<Vehicle?> watchActive(String userId) {
    final query = _db.select(_db.vehicleRecords).join([
      innerJoin(
        _db.userProfiles,
        _db.userProfiles.activeVehicleId.equalsExp(_db.vehicleRecords.id),
      ),
    ])..where(
        _db.userProfiles.userId.equals(userId) & _db.vehicleRecords.archived.equals(false),
      );
    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      return vehicleFromDrift(rows.first.readTable(_db.vehicleRecords));
    });
  }

  @override
  Future<Vehicle?> getById(String id) async {
    final row = await (_db.select(
      _db.vehicleRecords,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : vehicleFromDrift(row);
  }

  @override
  Future<Vehicle> add({
    required String userId,
    required VehicleDraft draft,
  }) async {
    await _assertUniquePlate(userId: userId, plate: draft.licensePlate);
    await _assertUniqueVin(vin: draft.vin);

    final now = DateTime.now().toUtc();
    final vehicle = Vehicle(
      id: _uuid.v4(),
      userId: userId,
      name: draft.name.trim(),
      nickname: _emptyToNull(draft.nickname),
      make: draft.make.trim(),
      model: draft.model.trim(),
      year: draft.year,
      licensePlate: draft.licensePlate.trim(),
      vin: _emptyToNull(draft.vin)?.toUpperCase(),
      color: _emptyToNull(draft.color),
      fuelType: draft.fuelType,
      mileage: draft.mileage,
      mileageUnit: draft.mileageUnit,
      purchaseDate: draft.purchaseDate,
      purchasePrice: draft.purchasePrice,
      photoLocalPath: draft.photoLocalPath,
      archived: false,
      updatedAt: now,
      createdAt: now,
    );

    await _db.transaction(() async {
      await _db.into(_db.vehicleRecords).insert(_toCompanion(vehicle));
      final garage = await _countGarage(userId);
      if (garage == 1) {
        await _upsertActive(userId, vehicle.id);
      }
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.vehicle,
        entityId: vehicle.id,
        op: OutboxOp.upsert,
        payload: vehicle.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return vehicle;
  }

  @override
  Future<Vehicle> update({
    required String userId,
    required String vehicleId,
    required VehicleDraft draft,
  }) async {
    final existing = await getById(vehicleId);
    if (existing == null || existing.userId != userId || existing.archived) {
      throw const VehicleNotFoundFailure();
    }
    if (draft.mileage < existing.mileage) {
      throw const MileageDecreaseFailure();
    }
    await _assertUniquePlate(
      userId: userId,
      plate: draft.licensePlate,
      exceptId: vehicleId,
    );
    await _assertUniqueVin(vin: draft.vin, exceptId: vehicleId);

    final updated = Vehicle(
      id: existing.id,
      userId: existing.userId,
      name: draft.name.trim(),
      nickname: _emptyToNull(draft.nickname),
      make: draft.make.trim(),
      model: draft.model.trim(),
      year: draft.year,
      licensePlate: draft.licensePlate.trim(),
      vin: _emptyToNull(draft.vin)?.toUpperCase(),
      color: _emptyToNull(draft.color),
      fuelType: draft.fuelType,
      mileage: draft.mileage,
      mileageUnit: draft.mileageUnit,
      purchaseDate: draft.purchaseDate,
      purchasePrice: draft.purchasePrice,
      photoLocalPath: draft.photoLocalPath ?? existing.photoLocalPath,
      photoMediaId: existing.photoMediaId,
      archived: false,
      updatedAt: DateTime.now().toUtc(),
      createdAt: existing.createdAt,
    );

    await _db.transaction(() async {
      await (_db.update(
        _db.vehicleRecords,
      )..where((row) => row.id.equals(vehicleId))).write(_toCompanion(updated));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.vehicle,
        entityId: updated.id,
        op: OutboxOp.upsert,
        payload: updated.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return updated;
  }

  @override
  Future<void> setActive({
    required String userId,
    required String vehicleId,
  }) async {
    final existing = await getById(vehicleId);
    if (existing == null || existing.userId != userId || existing.archived) {
      throw const VehicleNotFoundFailure();
    }
    await _upsertActive(userId, vehicleId);
  }

  @override
  Future<void> archive({
    required String userId,
    required String vehicleId,
  }) async {
    final existing = await getById(vehicleId);
    if (existing == null || existing.userId != userId) {
      throw const VehicleNotFoundFailure();
    }
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.vehicleRecords)..where((row) => row.id.equals(vehicleId))).write(
        VehicleRecordsCompanion(
          archived: const Value(true),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      final profile = await (_db.select(
        _db.userProfiles,
      )..where((row) => row.userId.equals(userId))).getSingleOrNull();
      if (profile?.activeVehicleId == vehicleId) {
        final next = await (_db.select(_db.vehicleRecords)
              ..where((row) => row.userId.equals(userId) & row.archived.equals(false))
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
        await _upsertActive(userId, next?.id);
      }
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.vehicle,
        entityId: vehicleId,
        op: OutboxOp.archive,
        payload: {'id': vehicleId, 'archived': true},
      );
    });
    await _sync.requestSync();
  }

  Future<void> _assertUniquePlate({
    required String userId,
    required String plate,
    String? exceptId,
  }) async {
    final query = _db.select(_db.vehicleRecords)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.archived.equals(false) &
            row.licensePlate.lower().equals(plate.trim().toLowerCase()),
      );
    final matches = await query.get();
    if (matches.any((row) => row.id != exceptId)) {
      throw const DuplicatePlateFailure();
    }
  }

  Future<void> _assertUniqueVin({required String? vin, String? exceptId}) async {
    final value = vin?.trim();
    if (value == null || value.isEmpty) return;
    final matches = await (_db.select(
      _db.vehicleRecords,
    )..where((row) => row.archived.equals(false) & row.vin.lower().equals(value.toLowerCase()))).get();
    if (matches.any((row) => row.id != exceptId)) {
      throw const DuplicateVinFailure();
    }
  }

  Future<int> _countGarage(String userId) {
    final count = _db.vehicleRecords.id.count();
    final query = _db.selectOnly(_db.vehicleRecords)
      ..addColumns([count])
      ..where(
        _db.vehicleRecords.userId.equals(userId) & _db.vehicleRecords.archived.equals(false),
      );
    return query.map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<void> _upsertActive(String userId, String? vehicleId) {
    return _db
        .into(_db.userProfiles)
        .insertOnConflictUpdate(
          UserProfilesCompanion.insert(
            userId: userId,
            activeVehicleId: Value(vehicleId),
          ),
        );
  }

  VehicleRecordsCompanion _toCompanion(Vehicle vehicle) {
    return VehicleRecordsCompanion.insert(
      id: vehicle.id,
      userId: vehicle.userId,
      name: vehicle.name,
      nickname: Value(vehicle.nickname),
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      licensePlate: vehicle.licensePlate,
      vin: Value(vehicle.vin),
      color: Value(vehicle.color),
      fuelType: vehicle.fuelType.storage,
      mileage: vehicle.mileage,
      mileageUnit: Value(vehicle.mileageUnit.name),
      purchaseDate: Value(vehicle.purchaseDate),
      purchasePrice: Value(vehicle.purchasePrice),
      photoLocalPath: Value(vehicle.photoLocalPath),
      photoMediaId: Value(vehicle.photoMediaId),
      archived: Value(vehicle.archived),
      archivedAt: Value(vehicle.archivedAt),
      updatedAt: vehicle.updatedAt,
      createdAt: vehicle.createdAt,
    );
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

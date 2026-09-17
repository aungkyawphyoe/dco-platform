import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'outbox_models.dart';
import 'sync_api.dart';

/// Applies one pulled server change to the local Drift tables.
///
/// Conflict rules (mobile/AGENTS.md):
/// - Vehicle mileage: max(local, remote), never decrease.
/// - Archive wins over any later edit of the same entity.
/// - Otherwise last-write-wins by remote timestamp vs local updatedAt.
class ChangeApplier {
  ChangeApplier(this._db);

  final AppDatabase _db;

  Future<void> apply(SyncChange change, {required String userId}) async {
    switch (change.entityType) {
      case OutboxEntityType.vehicle:
        await _applyVehicle(change, userId);
      case OutboxEntityType.planItem:
        await _applyPlanItem(change);
      case OutboxEntityType.serviceRecord:
        await _applyServiceRecord(change);
      case OutboxEntityType.part:
        await _applyPart(change, userId);
      case OutboxEntityType.fuelType:
        await _applyFuelType(change, userId);
      case OutboxEntityType.fuelLog:
        await _applyFuelLog(change, userId);
      case OutboxEntityType.expense:
        await _applyExpense(change);
      case OutboxEntityType.notification:
        await _applyNotification(change, userId);
      case OutboxEntityType.document:
        await _applyDocument(change);
      case OutboxEntityType.familyVehicle:
        await _applyFamilyVehicle(change);
      default:
      // media / user have no local tables yet; nothing to apply.
        break;
    }
  }

  Future<void> _applyVehicle(SyncChange change, String userId) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    final existing = await (_db.select(
      _db.vehicleRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final remoteMileage = _dbl(payload['mileage']) ?? existing?.mileage ?? 0;
    final effectiveMileage = existing == null
        ? remoteMileage
        : (existing.mileage > remoteMileage ? existing.mileage : remoteMileage);

    if (change.op == SyncChangeOp.archive) {
      if (existing == null) return;
      await (_db.update(_db.vehicleRecords)..where((row) => row.id.equals(id))).write(
        VehicleRecordsCompanion(
          archived: const Value(true),
          archivedAt: Value(
            _dt(payload['archived_at']) ?? change.serverTs,
          ),
          mileage: Value(effectiveMileage),
          updatedAt: Value(change.serverTs),
        ),
      );
      return;
    }
    if (change.op == SyncChangeOp.delete) return;

    if (existing != null && existing.archived) return;
    final remoteUpdatedAt = _dt(payload['updated_at']) ?? change.serverTs;
    if (existing != null && !remoteUpdatedAt.isAfter(existing.updatedAt)) {
      if (remoteMileage > existing.mileage) {
        await (_db.update(_db.vehicleRecords)..where((row) => row.id.equals(id))).write(
          VehicleRecordsCompanion(
            mileage: Value(remoteMileage),
            updatedAt: Value(remoteUpdatedAt),
          ),
        );
      }
      return;
    }

    final companion = VehicleRecordsCompanion.insert(
      id: id,
      userId: _str(payload['user_id'], fallback: userId),
      name: _str(payload['name']),
      nickname: Value(_strN(payload['nickname'])),
      make: _str(payload['make']),
      model: _str(payload['model']),
      year: _int(payload['year']) ?? existing?.year ?? 1900,
      licensePlate: _str(payload['license_plate'], fallback: ''),
      vin: Value(_strN(payload['vin'])),
      color: Value(_strN(payload['color'])),
      fuelType: _str(payload['fuel_type'], fallback: 'petrol'),
      mileage: effectiveMileage,
      mileageUnit: Value(_str(payload['mileage_unit'], fallback: 'mi')),
      purchaseDate: Value(_dateN(payload['purchase_date'])),
      purchasePrice: Value(_dbl(payload['purchase_price'])),
      photoLocalPath: Value(existing?.photoLocalPath),
      photoMediaId: Value(_strN(payload['photo_media_id']) ?? existing?.photoMediaId),
      archived: Value(existing?.archived ?? false),
      archivedAt: Value(_dt(payload['archived_at'])),
      updatedAt: remoteUpdatedAt,
      createdAt: existing?.createdAt ?? change.serverTs,
    );
    await _db.into(_db.vehicleRecords).insertOnConflictUpdate(companion);
  }

  Future<void> _applyPlanItem(SyncChange change) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.planItemRecords)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.planItemRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!_isWritable(change, existing?.updatedAt)) return;

    await _db.into(_db.planItemRecords).insertOnConflictUpdate(
      PlanItemRecordsCompanion.insert(
        id: id,
        vehicleId: _str(payload['vehicle_id'], fallback: existing?.vehicleId ?? ''),
        name: _str(payload['name']),
        intervalDays: Value(_int(payload['interval_days'])),
        intervalDistance: Value(_dbl(payload['interval_distance'])),
        nextDueMileage: Value(_dbl(payload['next_due_mileage'])),
        nextDueOn: Value(_dateN(payload['next_due_on'])),
        enabled: Value(payload['enabled'] as bool? ?? existing?.enabled ?? true),
        notes: Value(_strN(payload['notes'])),
        catalogKey: Value(_strN(payload['catalog_key'])),
        updatedAt: change.serverTs,
        createdAt: existing?.createdAt ?? change.serverTs,
      ),
    );
  }

  Future<void> _applyServiceRecord(SyncChange change) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.serviceLineRecords)
            ..where((row) => row.serviceRecordId.equals(id)))
          .go();
      await (_db.delete(_db.servicePartRecords)
            ..where((row) => row.serviceRecordId.equals(id)))
          .go();
      await (_db.delete(_db.serviceRecordRows)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.serviceRecordRows,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!_isWritable(change, existing?.updatedAt)) return;

    final items = _list(payload['items']);
    final parts = _list(payload['parts']);
    final derivedTitle = items.map((item) => _str(item['name'])).join(', ');

    await _db.into(_db.serviceRecordRows).insertOnConflictUpdate(
      ServiceRecordRowsCompanion.insert(
        id: id,
        vehicleId: _str(payload['vehicle_id'], fallback: existing?.vehicleId ?? ''),
        title: _str(payload['title'], fallback: derivedTitle),
        servicedOn: _date(payload['serviced_on']),
        odometer: _dbl(payload['odometer']) ?? 0,
        totalCost: _dbl(payload['total_cost']) ?? 0,
        workshopName: Value(_strN(payload['workshop_name'])),
        notes: Value(_strN(payload['notes'])),
        receiptLocalPath: Value(existing?.receiptLocalPath),
        receiptMediaId: Value(_strN(payload['receipt_media_id']) ?? existing?.receiptMediaId),
        updatedAt: change.serverTs,
        createdAt: existing?.createdAt ?? change.serverTs,
      ),
    );

    await (_db.delete(_db.serviceLineRecords)
          ..where((row) => row.serviceRecordId.equals(id)))
        .go();
    await (_db.delete(_db.servicePartRecords)
          ..where((row) => row.serviceRecordId.equals(id)))
        .go();
    for (final item in items) {
      await _db.into(_db.serviceLineRecords).insertOnConflictUpdate(
        ServiceLineRecordsCompanion.insert(
          id: _str(item['id'], fallback: _uuidLike(id, items.indexOf(item))),
          serviceRecordId: id,
          planItemId: Value(_strN(item['plan_item_id'])),
          name: _str(item['name']),
          lineCost: Value(_dbl(item['line_cost'])),
        ),
      );
    }
    for (final part in parts) {
      await _db.into(_db.servicePartRecords).insertOnConflictUpdate(
        ServicePartRecordsCompanion.insert(
          id: _str(part['id'], fallback: _uuidLike('$id-parts', parts.indexOf(part))),
          serviceRecordId: id,
          partId: _str(part['part_id']),
          name: _str(part['name']),
        ),
      );
    }
  }

  Future<void> _applyPart(SyncChange change, String userId) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.partRecords)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.partRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!_isWritable(change, existing?.updatedAt)) return;

    await _db.into(_db.partRecords).insertOnConflictUpdate(
      PartRecordsCompanion.insert(
        id: id,
        userId: _str(payload['user_id'], fallback: existing?.userId ?? userId),
        vehicleId: _str(payload['vehicle_id'], fallback: existing?.vehicleId ?? ''),
        name: _str(payload['name']),
        brand: Value(_strN(payload['brand'])),
        partNumber: Value(_strN(payload['part_number'])),
        notes: Value(_strN(payload['notes'])),
        updatedAt: change.serverTs,
        createdAt: existing?.createdAt ?? change.serverTs,
      ),
    );
  }

  Future<void> _applyFuelType(SyncChange change, String userId) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.fuelTypeRecords)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.fuelTypeRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!_isWritable(change, existing?.updatedAt)) return;

    await _db.into(_db.fuelTypeRecords).insertOnConflictUpdate(
      FuelTypeRecordsCompanion.insert(
        id: id,
        userId: _str(payload['user_id'], fallback: existing?.userId ?? userId),
        name: _str(payload['name']),
        kind: _str(payload['kind'], fallback: 'liquid'),
        unit: _str(payload['unit'], fallback: 'L'),
        updatedAt: change.serverTs,
        createdAt: existing?.createdAt ?? change.serverTs,
      ),
    );
  }

  Future<void> _applyFuelLog(SyncChange change, String userId) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.fuelLogRecords)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.fuelLogRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!_isWritable(change, existing?.updatedAt)) return;

    await _db.into(_db.fuelLogRecords).insertOnConflictUpdate(
      FuelLogRecordsCompanion.insert(
        id: id,
        userId: _str(payload['user_id'], fallback: existing?.userId ?? userId),
        vehicleId: _str(payload['vehicle_id'], fallback: existing?.vehicleId ?? ''),
        kind: _str(payload['kind'], fallback: 'refuel'),
        fuelTypeId: _str(payload['fuel_type_id'], fallback: ''),
        fuelTypeName: _str(payload['fuel_type_name']),
        unit: _str(payload['unit'], fallback: 'L'),
        loggedOn: _date(payload['logged_on']),
        amount: _dbl(payload['amount']) ?? 0,
        cost: _dbl(payload['cost']) ?? 0,
        updatedAt: change.serverTs,
        createdAt: existing?.createdAt ?? change.serverTs,
      ),
    );
  }

  Future<void> _applyExpense(SyncChange change) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.expensePartRecords)
            ..where((row) => row.expenseId.equals(id)))
          .go();
      await (_db.delete(_db.expenseRecords)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.expenseRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!_isWritable(change, existing?.updatedAt)) return;

    await _db.into(_db.expenseRecords).insertOnConflictUpdate(
      ExpenseRecordsCompanion.insert(
        id: id,
        vehicleId: _str(payload['vehicle_id'], fallback: existing?.vehicleId ?? ''),
        category: _str(payload['category'], fallback: 'other'),
        amount: _dbl(payload['amount']) ?? 0,
        incurredOn: _date(payload['incurred_on']),
        notes: Value(_strN(payload['notes'])),
        receiptLocalPath: Value(existing?.receiptLocalPath),
        receiptMediaId: Value(_strN(payload['receipt_media_id']) ?? existing?.receiptMediaId),
        updatedAt: change.serverTs,
        createdAt: existing?.createdAt ?? change.serverTs,
      ),
    );

    await (_db.delete(_db.expensePartRecords)..where((row) => row.expenseId.equals(id)))
        .go();
    final parts = _list(payload['parts']);
    for (final part in parts) {
      await _db.into(_db.expensePartRecords).insertOnConflictUpdate(
        ExpensePartRecordsCompanion.insert(
          id: _str(part['id'], fallback: _uuidLike(id, parts.indexOf(part))),
          expenseId: id,
          partId: _str(part['part_id']),
          name: _str(part['name']),
        ),
      );
    }
  }

  Future<void> _applyNotification(SyncChange change, String userId) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.notificationRecords)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.notificationRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!_isWritable(change, existing?.updatedAt)) return;

    await _db.into(_db.notificationRecords).insertOnConflictUpdate(
      NotificationRecordsCompanion.insert(
        id: id,
        userId: _str(payload['user_id'], fallback: existing?.userId ?? userId),
        vehicleId: Value(_strN(payload['vehicle_id'])),
        planItemId: Value(_strN(payload['plan_item_id'])),
        title: _str(payload['title']),
        body: _str(payload['body']),
        status: Value(_str(payload['status'], fallback: 'unread')),
        dueReason: Value(_strN(payload['due_reason'])),
        cycleKey: Value(_strN(payload['cycle_key']) ?? existing?.cycleKey),
        createdAt: _dt(payload['created_at']) ?? change.serverTs,
        updatedAt: change.serverTs,
      ),
    );
  }

  Future<void> _applyFamilyVehicle(SyncChange change) async {
    final payload = change.payload;
    final id = _idOf(payload, change);
    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.familyVehicleRecords)..where((row) => row.id.equals(id))).go();
      return;
    }
    final existing = await (_db.select(
      _db.familyVehicleRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();

    await _db.into(_db.familyVehicleRecords).insertOnConflictUpdate(
      FamilyVehicleRecordsCompanion.insert(
        id: id,
        familyId: _str(payload['family_id']),
        vehicleId: _str(payload['vehicle_id']),
        addedBy: _str(payload['added_by']),
        addedAt: _dt(payload['added_at']) ?? change.serverTs,
        syncedAt: Value(change.serverTs),
      ),
    );
  }

  Future<void> _applyDocument(SyncChange change) async {
    final payload = change.payload;
    final id = _idOf(payload, change);

    if (change.op == SyncChangeOp.delete) {
      await (_db.delete(_db.documentRecords)..where((row) => row.id.equals(id))).go();
      return;
    }

    final existing = await (_db.select(
      _db.documentRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();

    if (existing != null && !_isWritable(change, existing.updatedAt)) return;

    final remoteUpdatedAt = _dt(payload['updated_at']) ?? change.serverTs;

    if (existing != null) {
      await (_db.update(_db.documentRecords)..where((row) => row.id.equals(id))).write(
        DocumentRecordsCompanion(
          name: Value(_str(payload['name'], fallback: existing.name)),
          category: Value(_str(payload['category'], fallback: existing.category)),
          notes: Value(_strN(payload['notes']) ?? existing.notes),
          mediaId: Value(_strN(payload['media_id']) ?? existing.mediaId),
          updatedAt: Value(remoteUpdatedAt),
        ),
      );
    } else {
      await _db.into(_db.documentRecords).insert(
        DocumentRecordsCompanion.insert(
          id: id,
          vehicleId: _str(payload['vehicle_id']),
          name: _str(payload['name']),
          category: _str(payload['category'], fallback: 'other'),
          notes: Value(_strN(payload['notes'])),
          mediaId: Value(_strN(payload['media_id'])),
          updatedAt: remoteUpdatedAt,
          createdAt: _dt(payload['created_at']) ?? remoteUpdatedAt,
        ),
      );
    }
  }

  bool _isWritable(SyncChange change, DateTime? localUpdatedAt) {
    if (change.op == SyncChangeOp.archive) return true;
    return localUpdatedAt == null || change.serverTs.isAfter(localUpdatedAt);
  }

  String _idOf(Map<String, dynamic> payload, SyncChange change) {
    return _str(payload['id'], fallback: change.entityId);
  }
}

String _str(Object? value, {String fallback = ''}) {
  if (value is String && value.isNotEmpty) return value;
  return fallback;
}

String? _strN(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

double? _dbl(Object? value) => value is num ? value.toDouble() : null;

int? _int(Object? value) => value is int ? value : (value is num ? value.round() : null);

DateTime? _dt(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

DateTime _date(Object? value) {
  final parsed = _dt(value) ?? _dateN(value);
  if (parsed != null) return parsed;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _dateN(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final normalized = value.length >= 10 ? value.substring(0, 10) : value;
  return DateTime.tryParse(normalized);
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

// Deterministic stand-in when the server omits child ids.
String _uuidLike(String seed, int index) => '$seed-child-$index';

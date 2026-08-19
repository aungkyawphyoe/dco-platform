import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../garage/domain/entities/vehicle.dart';
import '../../domain/due_calculator.dart';
import '../../domain/entities/plan_item.dart';
import '../../domain/entities/service_record.dart';
import '../../domain/entities/suggested_plan_item.dart';
import '../../domain/maintenance_failure.dart';
import '../../domain/plan_item_validators.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/suggested_catalog.dart';
import '../mappers/maintenance_mapper.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl({
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
  Stream<List<PlanItem>> watchPlan(String vehicleId) {
    final query = _db.select(_db.planItemRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.name),
      ]);
    return query.watch().map((rows) => rows.map(planItemFromDrift).toList());
  }

  @override
  Stream<List<ServiceRecord>> watchHistory(String vehicleId) {
    final query = _db.select(_db.serviceRecordRows)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([(row) => OrderingTerm.desc(row.servicedOn)]);
    return query.watch().asyncMap(_attachLines);
  }

  @override
  Future<PlanItem?> getPlanItem(String id) async {
    final row = await (_db.select(
      _db.planItemRecords,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : planItemFromDrift(row);
  }

  @override
  Future<ServiceRecord?> getServiceRecord(String id) async {
    final row = await (_db.select(
      _db.serviceRecordRows,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final attached = await _attachLines([row]);
    return attached.single;
  }

  @override
  Future<bool> hasPlan(String vehicleId) async {
    final count = _db.planItemRecords.id.count();
    final query = _db.selectOnly(_db.planItemRecords)
      ..addColumns([count])
      ..where(_db.planItemRecords.vehicleId.equals(vehicleId));
    return (await query.map((row) => row.read(count) ?? 0).getSingle()) > 0;
  }

  @override
  Future<void> ensureDefaultPlan({
    required String userId,
    required Vehicle vehicle,
  }) async {
    if (await hasPlan(vehicle.id)) return;
    await addPlanItem(
      userId: userId,
      vehicle: vehicle,
      draft: DefaultPlanItems.mileageUpdateDraft(),
    );
    await addPlanItem(
      userId: userId,
      vehicle: vehicle,
      draft: DefaultPlanItems.routineDraft(),
    );
  }

  @override
  Future<PlanItem> addPlanItem({
    required String userId,
    required Vehicle vehicle,
    required PlanItemDraft draft,
  }) async {
    _assertDraft(draft);
    final now = DateTime.now().toUtc();
    final due = DueCalculator.fromDraft(
      draft: draft,
      now: now,
      currentMileage: vehicle.mileage,
    );
    final item = PlanItem(
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      name: draft.name.trim(),
      intervalDays: draft.recurring ? draft.intervalDays : null,
      intervalDistance: draft.recurring ? draft.intervalDistance : null,
      nextDueMileage: due.mileage,
      nextDueOn: due.on,
      enabled: draft.enabled,
      notes: _emptyToNull(draft.notes),
      catalogKey: draft.catalogKey,
      updatedAt: now,
      createdAt: now,
    );
    await _db.transaction(() async {
      await _db.into(_db.planItemRecords).insert(planItemToCompanion(item));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.planItem,
        entityId: item.id,
        op: OutboxOp.upsert,
        payload: item.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return item;
  }

  @override
  Future<PlanItem> updatePlanItem({
    required String userId,
    required Vehicle vehicle,
    required String planItemId,
    required PlanItemDraft draft,
  }) async {
    _assertDraft(draft);
    final existing = await getPlanItem(planItemId);
    if (existing == null || existing.vehicleId != vehicle.id) {
      throw const PlanItemNotFoundFailure();
    }
    final now = DateTime.now().toUtc();
    final due = DueCalculator.fromDraft(
      draft: draft,
      now: now,
      currentMileage: vehicle.mileage,
    );
    final updated = PlanItem(
      id: existing.id,
      vehicleId: existing.vehicleId,
      name: draft.name.trim(),
      intervalDays: draft.recurring ? draft.intervalDays : null,
      intervalDistance: draft.recurring ? draft.intervalDistance : null,
      nextDueMileage: due.mileage,
      nextDueOn: due.on,
      enabled: draft.enabled,
      notes: _emptyToNull(draft.notes),
      catalogKey: existing.catalogKey ?? draft.catalogKey,
      updatedAt: now,
      createdAt: existing.createdAt,
    );
    await _db.transaction(() async {
      await (_db.update(
        _db.planItemRecords,
      )..where((row) => row.id.equals(planItemId))).write(planItemToCompanion(updated));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.planItem,
        entityId: updated.id,
        op: OutboxOp.upsert,
        payload: updated.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return updated;
  }

  @override
  Future<void> addSuggestedItem({
    required String userId,
    required Vehicle vehicle,
    required SuggestedPlanItem suggestion,
  }) async {
    final existing = await (_db.select(_db.planItemRecords)..where(
      (row) =>
          row.vehicleId.equals(vehicle.id) &
          row.catalogKey.equals(suggestion.catalogKey),
    )).get();
    if (existing.isNotEmpty) return;
    await addPlanItem(
      userId: userId,
      vehicle: vehicle,
      draft: PlanItemDraft(
        name: suggestion.name,
        recurring: suggestion.recurring,
        intervalDays: suggestion.intervalDays,
        intervalDistance: suggestion.intervalDistance,
        catalogKey: suggestion.catalogKey,
      ),
    );
  }

  @override
  Future<ServiceRecord> registerService({
    required String userId,
    required Vehicle vehicle,
    required ServiceRecordDraft draft,
  }) async {
    if (draft.items.isEmpty) {
      throw const MaintenanceValidationFailure('Add at least one service');
    }
    if (draft.odometer < 0) {
      throw const MaintenanceValidationFailure('Enter a valid mileage');
    }
    if (draft.odometer < vehicle.mileage) {
      throw const MileageDecreaseFailure();
    }
    if (draft.totalCost < 0) {
      throw const MaintenanceValidationFailure('Enter a valid amount');
    }

    final now = DateTime.now().toUtc();
    final lines = draft.items
        .map(
          (item) => ServiceLine(
            id: _uuid.v4(),
            planItemId: item.planItemId,
            name: item.name.trim(),
            lineCost: item.lineCost,
          ),
        )
        .toList();
    final title = _emptyToNull(draft.title) ?? lines.map((line) => line.name).join(', ');
    final record = ServiceRecord(
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      title: title,
      servicedOn: DueCalculator.dateOnly(draft.servicedOn),
      odometer: draft.odometer,
      totalCost: draft.totalCost,
      workshopName: _emptyToNull(draft.workshopName),
      notes: _emptyToNull(draft.notes),
      items: lines,
      updatedAt: now,
      createdAt: now,
    );

    await _db.transaction(() async {
      await _db
          .into(_db.serviceRecordRows)
          .insert(
            ServiceRecordRowsCompanion.insert(
              id: record.id,
              vehicleId: record.vehicleId,
              title: record.title,
              servicedOn: record.servicedOn,
              odometer: record.odometer,
              totalCost: record.totalCost,
              workshopName: Value(record.workshopName),
              notes: Value(record.notes),
              updatedAt: record.updatedAt,
              createdAt: record.createdAt,
            ),
          );
      for (final line in lines) {
        await _db
            .into(_db.serviceLineRecords)
            .insert(
              ServiceLineRecordsCompanion.insert(
                id: line.id,
                serviceRecordId: record.id,
                planItemId: Value(line.planItemId),
                name: line.name,
                lineCost: Value(line.lineCost),
              ),
            );
      }

      if (draft.odometer > vehicle.mileage) {
        await (_db.update(_db.vehicleRecords)..where((row) => row.id.equals(vehicle.id))).write(
          VehicleRecordsCompanion(
            mileage: Value(draft.odometer),
            updatedAt: Value(now),
          ),
        );
        await _outbox.enqueue(
          userId: userId,
          entityType: OutboxEntityType.vehicle,
          entityId: vehicle.id,
          op: OutboxOp.upsert,
          payload: vehicle.toWriteJson()..['mileage'] = draft.odometer,
        );
      }

      final completedIds = lines.map((line) => line.planItemId).whereType<String>().toSet();
      for (final planItemId in completedIds) {
        final item = await getPlanItem(planItemId);
        if (item == null || item.vehicleId != vehicle.id) continue;
        final next = DueCalculator.afterService(
          item: item,
          servicedOn: record.servicedOn,
          odometer: record.odometer,
        );
        final updated = PlanItem(
          id: item.id,
          vehicleId: item.vehicleId,
          name: item.name,
          intervalDays: item.intervalDays,
          intervalDistance: item.intervalDistance,
          nextDueMileage: next.mileage,
          nextDueOn: next.on,
          enabled: item.recurring,
          notes: item.notes,
          catalogKey: item.catalogKey,
          updatedAt: now,
          createdAt: item.createdAt,
        );
        await (_db.update(
          _db.planItemRecords,
        )..where((row) => row.id.equals(item.id))).write(planItemToCompanion(updated));
        await _outbox.enqueue(
          userId: userId,
          entityType: OutboxEntityType.planItem,
          entityId: updated.id,
          op: OutboxOp.upsert,
          payload: updated.toWriteJson(),
        );
      }

      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.serviceRecord,
        entityId: record.id,
        op: OutboxOp.upsert,
        payload: record.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return record;
  }

  Future<List<ServiceRecord>> _attachLines(List<ServiceRecordRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toList();
    final lines = await (_db.select(
      _db.serviceLineRecords,
    )..where((row) => row.serviceRecordId.isIn(ids))).get();
    final byRecord = <String, List<ServiceLineRecord>>{};
    for (final line in lines) {
      byRecord.putIfAbsent(line.serviceRecordId, () => []).add(line);
    }
    return rows
        .map((row) => serviceRecordFromDrift(row, byRecord[row.id] ?? const []))
        .toList();
  }

  void _assertDraft(PlanItemDraft draft) {
    final nameError = PlanItemValidators.name(draft.name);
    if (nameError != null) throw MaintenanceValidationFailure(nameError);
    final scheduleError = PlanItemValidators.schedule(
      recurring: draft.recurring,
      intervalDays: draft.intervalDays,
      intervalDistance: draft.intervalDistance,
      date: draft.date,
      mileage: draft.mileage,
    );
    if (scheduleError != null) throw MaintenanceValidationFailure(scheduleError);
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

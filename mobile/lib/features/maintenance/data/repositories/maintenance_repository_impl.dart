import '../../../../core/currency/currency_store.dart';
import '../../../../core/database/document_links.dart';
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
import '../../domain/maintenance_failure.dart';
import '../../domain/plan_item_validators.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../mappers/maintenance_mapper.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../../../expenses/domain/entities/expense.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl({
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

  @override
  Future<void> deleteService({
    required String userId,
    required String serviceRecordId,
  }) async {
    final record = await getServiceRecord(serviceRecordId);
    if (record == null) return;
    await _db.transaction(() async {
      await detachDocumentLinks(_db, 'service_record', serviceRecordId);
      await _outbox.enqueue(
        userId: userId,
        entityType: 'service_record',
        entityId: serviceRecordId,
        op: OutboxOp.delete,
        payload: {'id': serviceRecordId, 'vehicle_id': record.vehicleId},
      );
      await (_db.delete(
        _db.serviceLineRecords,
      )..where((r) => r.serviceRecordId.equals(serviceRecordId))).go();
      await (_db.delete(
        _db.servicePartRecords,
      )..where((r) => r.serviceRecordId.equals(serviceRecordId))).go();
      await (_db.delete(
        _db.serviceRecordRows,
      )..where((r) => r.id.equals(serviceRecordId))).go();
      if (!_outbox.derivesExpenses &&
          await _expenseRepository.getById(record.id) != null) {
        await _expenseRepository.delete(userId: userId, expenseId: record.id);
      }
      await _recalculateReminders(record.vehicleId);
    });
    _sync?.requestSync();
  }

  @override
  Stream<List<PlanItem>> watchPlan(String vehicleId) {
    final query = _db.select(_db.planItemRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.watch().map((rows) => rows.map(planItemFromDrift).toList());
  }

  @override
  Stream<List<PlanItem>> watchAllPlans(String userId) {
    final query = _db.select(_db.planItemRecords).join([
      innerJoin(
        _db.vehicleRecords,
        _db.vehicleRecords.id.equalsExp(_db.planItemRecords.vehicleId),
      ),
    ])..where(_db.vehicleRecords.userId.equals(userId));
    return query.watch().map(
      (rows) => rows
          .map((row) => planItemFromDrift(row.readTable(_db.planItemRecords)))
          .toList(),
    );
  }

  @override
  Stream<List<ServiceRecord>> watchHistory(String vehicleId) {
    final query = _db.select(_db.serviceRecordRows)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([
        (row) => OrderingTerm.desc(row.servicedOn),
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch().asyncMap(_attachChildren);
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
    final attached = await _attachChildren([row]);
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
      baselineDueOn: due.on,
      baselineDueMileage: due.mileage,
      baselineEnabled: draft.enabled,
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      name: draft.name.trim(),
      timeCount: draft.recurring ? draft.timeCount : null,
      timeUnit: draft.recurring ? draft.timeUnit : null,
      warningDays: draft.warningDays,
      warningDistance: draft.warningDistance,
      intervalDays: draft.recurring ? draft.intervalDays : null,
      intervalDistance: draft.recurring ? draft.intervalDistance : null,
      nextDueMileage: due.mileage,
      nextDueOn: due.on,
      enabled: draft.enabled,
      notes: _emptyToNull(draft.notes),
      catalogKey: draft.catalogKey,
      createdBy: userId,
      updatedAt: now,
      createdAt: now,
    );
    await _db.transaction(() async {
      await _assertUniqueCatalogReminder(item);
      await _db.into(_db.planItemRecords).insert(planItemToCompanion(item));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.planItem,
        entityId: item.id,
        op: OutboxOp.upsert,
        payload: item.toWriteJson(),
      );
    });
    _sync?.requestSync();
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
    final history = await watchHistory(vehicle.id).first;
    final previous = history
        .where(
          (record) => record.items.any((line) => line.planItemId == planItemId),
        )
        .firstOrNull;
    final updated = PlanItem(
      baselineDueOn: due.on,
      baselineDueMileage: due.mileage,
      baselineEnabled: draft.enabled,
      manualOn: DueCalculator.dateOnly(now),
      manualServiceId: previous?.id,
      id: existing.id,
      vehicleId: existing.vehicleId,
      name: draft.name.trim(),
      timeCount: draft.recurring ? draft.timeCount : null,
      timeUnit: draft.recurring ? draft.timeUnit : null,
      warningDays: draft.warningDays,
      warningDistance: draft.warningDistance,
      intervalDays: draft.recurring ? draft.intervalDays : null,
      intervalDistance: draft.recurring ? draft.intervalDistance : null,
      nextDueMileage: due.mileage,
      nextDueOn: due.on,
      enabled: draft.enabled,
      notes: _emptyToNull(draft.notes),
      catalogKey: existing.catalogKey ?? draft.catalogKey,
      createdBy: existing.createdBy,
      updatedAt: now,
      createdAt: existing.createdAt,
    );
    await _db.transaction(() async {
      await _assertUniqueCatalogReminder(updated);
      await (_db.update(_db.planItemRecords)
            ..where((row) => row.id.equals(planItemId)))
          .write(planItemToCompanion(updated));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.planItem,
        entityId: updated.id,
        op: OutboxOp.upsert,
        payload: updated.toWriteJson(),
      );
    });
    _sync?.requestSync();
    return updated;
  }

  @override
  Future<ServiceRecord> registerService({
    required String userId,
    required Vehicle vehicle,
    required ServiceRecordDraft draft,
  }) async {
    await _validateServiceLinks(vehicle.id, draft);
    if (draft.items.isEmpty) {
      throw const MaintenanceValidationFailure('Add at least one service');
    }
    if (draft.odometer != null && draft.odometer! < 0) {
      throw const MaintenanceValidationFailure('Enter a valid odometer');
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
    final assigned = draft.parts
        .map(
          (part) => AssignedPart(
            id: _uuid.v4(),
            partId: part.partId,
            name: part.name.trim(),
          ),
        )
        .toList();
    final title =
        _emptyToNull(draft.title) ?? lines.map((line) => line.name).join(', ');
    final record = ServiceRecord(
      currency: await CurrencyStore(_db).validateCreation(
        userId,
        draft.currency ?? 'MMK',
        vehicleId: vehicle.id,
      ),
      id: _uuid.v4(),
      vehicleId: vehicle.id,
      title: title,
      servicedOn: DueCalculator.dateOnly(draft.servicedOn),
      odometer: draft.odometer,
      totalCost: draft.totalCost,
      workshopName: _emptyToNull(draft.workshopName),
      notes: _emptyToNull(draft.notes),
      items: lines,
      parts: assigned,
      updatedAt: now,
      createdAt: now,
      createdBy: userId,
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
              odometer: Value(record.odometer),
              totalCost: record.totalCost,
              currency: Value(record.currency),
              workshopName: Value(record.workshopName),
              notes: Value(record.notes),
              createdBy: Value(record.createdBy),
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
      for (final part in assigned) {
        await _db
            .into(_db.servicePartRecords)
            .insert(
              ServicePartRecordsCompanion.insert(
                id: part.id,
                serviceRecordId: record.id,
                partId: part.partId,
                name: part.name,
              ),
            );
      }

      if (draft.odometer != null && draft.odometer! > vehicle.mileage) {
        await (_db.update(
          _db.vehicleRecords,
        )..where((row) => row.id.equals(vehicle.id))).write(
          VehicleRecordsCompanion(
            mileage: Value(draft.odometer!),
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

      await _recalculateReminders(vehicle.id);

      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.serviceRecord,
        entityId: record.id,
        op: OutboxOp.upsert,
        payload: record.toWriteJson(),
      );
      // Auto-create expense for maintenance cost (skip if zero — e.g. mileage-only updates)
      if (draft.totalCost > 0 && !_outbox.derivesExpenses) {
        await _expenseRepository.add(
          userId: userId,
          vehicleId: vehicle.id,
          draft: ExpenseDraft(
            currency: record.currency,
            currencyParentId: record.id,
            category: ExpenseCategory.maintenance,
            amount: draft.totalCost,
            incurredOn: draft.servicedOn,
          ),
        );
      }
    });
    _sync?.requestSync();
    return record;
  }

  @override
  Future<ServiceRecord> updateService({
    required String userId,
    required Vehicle vehicle,
    required String serviceRecordId,
    required ServiceRecordDraft draft,
  }) async {
    await _validateServiceLinks(vehicle.id, draft);
    if (draft.items.isEmpty) {
      throw const MaintenanceValidationFailure('Add at least one service');
    }
    if (draft.odometer != null && draft.odometer! < 0) {
      throw const MaintenanceValidationFailure('Enter a valid odometer');
    }
    if (draft.totalCost < 0) {
      throw const MaintenanceValidationFailure('Enter a valid amount');
    }

    final existing = await getServiceRecord(serviceRecordId);
    if (existing == null || existing.vehicleId != vehicle.id) {
      throw const ServiceRecordNotFoundFailure();
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
    final assigned = draft.parts
        .map(
          (part) => AssignedPart(
            id: _uuid.v4(),
            partId: part.partId,
            name: part.name.trim(),
          ),
        )
        .toList();
    final title =
        _emptyToNull(draft.title) ?? lines.map((line) => line.name).join(', ');
    final record = ServiceRecord(
      id: existing.id,
      currency: draft.currency ?? existing.currency,
      vehicleId: existing.vehicleId,
      title: title,
      servicedOn: DueCalculator.dateOnly(draft.servicedOn),
      odometer: draft.odometer,
      totalCost: draft.totalCost,
      workshopName: _emptyToNull(draft.workshopName),
      notes: _emptyToNull(draft.notes),
      items: lines,
      parts: assigned,
      receiptLocalPath: existing.receiptLocalPath,
      receiptMediaId: existing.receiptMediaId,
      updatedAt: now,
      createdAt: existing.createdAt,
      createdBy: existing.createdBy,
    );

    await _db.transaction(() async {
      await (_db.update(
        _db.serviceRecordRows,
      )..where((row) => row.id.equals(serviceRecordId))).write(
        ServiceRecordRowsCompanion(
          title: Value(record.title),
          servicedOn: Value(record.servicedOn),
          odometer: Value(record.odometer),
          totalCost: Value(record.totalCost),
          currency: Value(record.currency),
          workshopName: Value(record.workshopName),
          notes: Value(record.notes),
          updatedAt: Value(record.updatedAt),
        ),
      );
      await (_db.delete(
        _db.serviceLineRecords,
      )..where((row) => row.serviceRecordId.equals(serviceRecordId))).go();
      await (_db.delete(
        _db.servicePartRecords,
      )..where((row) => row.serviceRecordId.equals(serviceRecordId))).go();
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
      for (final part in assigned) {
        await _db
            .into(_db.servicePartRecords)
            .insert(
              ServicePartRecordsCompanion.insert(
                id: part.id,
                serviceRecordId: record.id,
                partId: part.partId,
                name: part.name,
              ),
            );
      }

      if (draft.odometer != null && draft.odometer! > vehicle.mileage) {
        await (_db.update(
          _db.vehicleRecords,
        )..where((row) => row.id.equals(vehicle.id))).write(
          VehicleRecordsCompanion(
            mileage: Value(draft.odometer!),
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

      await _recalculateReminders(vehicle.id);
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.serviceRecord,
        entityId: record.id,
        op: OutboxOp.upsert,
        payload: record.toWriteJson(),
      );
      if (!_outbox.derivesExpenses &&
          await _expenseRepository.getById(record.id) != null) {
        await _expenseRepository.update(
          userId: userId,
          expenseId: record.id,
          draft: ExpenseDraft(
            currency: record.currency,
            category: ExpenseCategory.maintenance,
            amount: record.totalCost,
            incurredOn: record.servicedOn,
          ),
        );
      }
    });
    _sync?.requestSync();
    return record;
  }

  Future<List<ServiceRecord>> _attachChildren(
    List<ServiceRecordRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toList();
    final lines = await (_db.select(
      _db.serviceLineRecords,
    )..where((row) => row.serviceRecordId.isIn(ids))).get();
    final parts = await (_db.select(
      _db.servicePartRecords,
    )..where((row) => row.serviceRecordId.isIn(ids))).get();
    final linesByRecord = <String, List<ServiceLineRecord>>{};
    for (final line in lines) {
      linesByRecord.putIfAbsent(line.serviceRecordId, () => []).add(line);
    }
    final partsByRecord = <String, List<ServicePartRecord>>{};
    for (final part in parts) {
      partsByRecord.putIfAbsent(part.serviceRecordId, () => []).add(part);
    }
    return rows
        .map(
          (row) => serviceRecordFromDrift(
            row,
            linesByRecord[row.id] ?? const [],
            partsByRecord[row.id] ?? const [],
          ),
        )
        .toList();
  }

  Future<void> _validateServiceLinks(
    String vehicleId,
    ServiceRecordDraft draft,
  ) async {
    for (final id
        in draft.items
            .map((item) => item.planItemId)
            .whereType<String>()
            .toSet()) {
      final plan = await getPlanItem(id);
      if (plan == null || plan.vehicleId != vehicleId) {
        throw const MaintenanceValidationFailure(
          'Select a reminder belonging to this vehicle',
        );
      }
      if (plan.intervalDistance != null && draft.odometer == null) {
        throw const MaintenanceValidationFailure(
          'Odometer is required for a distance repeat',
        );
      }
    }
  }

  Future<void> _recalculateReminders(String vehicleId) async {
    final plans = await watchPlan(vehicleId).first;
    final history = await watchHistory(vehicleId).first;
    for (final plan in plans) {
      final matches =
          history
              .where(
                (record) =>
                    record.items.any((line) => line.planItemId == plan.id),
              )
              .toList()
            ..sort((a, b) {
              final date = b.servicedOn.compareTo(a.servicedOn);
              if (date != 0) return date;
              final mileage = (b.odometer ?? -1).compareTo(a.odometer ?? -1);
              return mileage != 0 ? mileage : b.id.compareTo(a.id);
            });
      final last = matches.firstOrNull;
      final manual =
          last != null &&
          plan.manualOn != null &&
          (last.servicedOn.isBefore(plan.manualOn!) ||
              last.id == plan.manualServiceId);
      final next = last == null || manual
          ? NextDue(on: plan.baselineDueOn, mileage: plan.baselineDueMileage)
          : DueCalculator.afterService(
              item: plan,
              servicedOn: last.servicedOn,
              odometer: last.odometer ?? 0,
            );
      final hasReplacement =
          plan.catalogKey != null &&
          plans.any(
            (other) =>
                other.id != plan.id &&
                other.catalogKey == plan.catalogKey &&
                other.enabled,
          );
      final enabled =
          !hasReplacement &&
          (last == null || manual
              ? plan.baselineEnabled
              : plan.recurring && plan.baselineEnabled);
      await (_db.update(
        _db.planItemRecords,
      )..where((row) => row.id.equals(plan.id))).write(
        PlanItemRecordsCompanion(
          nextDueOn: Value(next.on),
          nextDueMileage: Value(next.mileage),
          enabled: Value(enabled),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  Future<void> _assertUniqueCatalogReminder(PlanItem item) async {
    final key = item.catalogKey;
    if (!item.enabled || key == null) return;
    final existing =
        await (_db.select(_db.planItemRecords)..where(
              (row) =>
                  row.vehicleId.equals(item.vehicleId) &
                  row.catalogKey.equals(key) &
                  row.enabled.equals(true),
            ))
            .get();
    if (existing.any((row) => row.id != item.id)) {
      throw const MaintenanceValidationFailure(
        'This service already has an active reminder. Edit the existing reminder.',
      );
    }
  }

  void _assertDraft(PlanItemDraft draft) {
    final nameError = PlanItemValidators.name(draft.name);
    if (nameError != null) throw MaintenanceValidationFailure(nameError);
    final scheduleError = PlanItemValidators.schedule(
      recurring: draft.recurring,
      timeCount: draft.timeCount,
      timeUnit: draft.timeUnit,
      intervalDays: draft.intervalDays,
      intervalDistance: draft.intervalDistance,
      date: draft.date,
      mileage: draft.mileage,
    );
    if (scheduleError != null) {
      throw MaintenanceValidationFailure(scheduleError);
    }
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

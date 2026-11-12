import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/plan_item.dart';
import '../../domain/entities/service_record.dart';

PlanItem planItemFromDrift(PlanItemRecord row) {
  return PlanItem(
    id: row.id,
    vehicleId: row.vehicleId,
    name: row.name,
    baselineDueOn: row.baselineDueOn,
    baselineDueMileage: row.baselineDueMileage,
    manualOn: row.manualOn,
    manualServiceId: row.manualServiceId,
    baselineEnabled: row.baselineEnabled,
    timeCount: row.timeCount,
    timeUnit: row.timeUnit,
    warningDays: row.warningDays,
    warningDistance: row.warningDistance,
    intervalDays: row.intervalDays,
    intervalDistance: row.intervalDistance,
    nextDueMileage: row.nextDueMileage,
    nextDueOn: row.nextDueOn,
    enabled: row.enabled,
    initialServiceRequired: row.initialServiceRequired,
    notes: row.notes,
    catalogKey: row.catalogKey,
    createdBy: row.createdBy,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

PlanItemRecordsCompanion planItemToCompanion(PlanItem item) {
  return PlanItemRecordsCompanion.insert(
    id: item.id,
    vehicleId: item.vehicleId,
    name: item.name,
    baselineDueOn: Value(item.baselineDueOn),
    baselineDueMileage: Value(item.baselineDueMileage),
    manualOn: Value(item.manualOn),
    manualServiceId: Value(item.manualServiceId),
    baselineEnabled: Value(item.baselineEnabled),
    timeCount: Value(item.timeCount),
    timeUnit: Value(item.timeUnit),
    warningDays: Value(item.warningDays),
    warningDistance: Value(item.warningDistance),
    intervalDays: Value(item.intervalDays),
    intervalDistance: Value(item.intervalDistance),
    nextDueMileage: Value(item.nextDueMileage),
    nextDueOn: Value(item.nextDueOn),
    enabled: Value(item.enabled),
    initialServiceRequired: Value(item.initialServiceRequired),
    notes: Value(item.notes),
    catalogKey: Value(item.catalogKey),
    createdBy: Value(item.createdBy),
    updatedAt: item.updatedAt,
    createdAt: item.createdAt,
  );
}

ServiceRecord serviceRecordFromDrift(
  ServiceRecordRow row,
  List<ServiceLineRecord> lines, [
  List<ServicePartRecord> parts = const [],
]) {
  return ServiceRecord(
    id: row.id,
    vehicleId: row.vehicleId,
    title: row.title,
    servicedOn: row.servicedOn,
    odometer: row.odometer,
    totalCost: row.totalCost,
    currency: row.currency,
    workshopName: row.workshopName,
    notes: row.notes,
    receiptLocalPath: row.receiptLocalPath,
    receiptMediaId: row.receiptMediaId,
    items: lines.map(serviceLineFromDrift).toList(),
    parts: parts.map(assignedPartFromDrift).toList(),
    createdBy: row.createdBy,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

ServiceLine serviceLineFromDrift(ServiceLineRecord row) {
  return ServiceLine(
    id: row.id,
    planItemId: row.planItemId,
    name: row.name,
    lineCost: row.lineCost,
  );
}

AssignedPart assignedPartFromDrift(ServicePartRecord row) {
  return AssignedPart(id: row.id, partId: row.partId, name: row.name);
}

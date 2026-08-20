import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/plan_item.dart';
import '../../domain/entities/service_record.dart';

PlanItem planItemFromDrift(PlanItemRecord row) {
  return PlanItem(
    id: row.id,
    vehicleId: row.vehicleId,
    name: row.name,
    intervalDays: row.intervalDays,
    intervalDistance: row.intervalDistance,
    nextDueMileage: row.nextDueMileage,
    nextDueOn: row.nextDueOn,
    enabled: row.enabled,
    notes: row.notes,
    catalogKey: row.catalogKey,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

PlanItemRecordsCompanion planItemToCompanion(PlanItem item) {
  return PlanItemRecordsCompanion.insert(
    id: item.id,
    vehicleId: item.vehicleId,
    name: item.name,
    intervalDays: Value(item.intervalDays),
    intervalDistance: Value(item.intervalDistance),
    nextDueMileage: Value(item.nextDueMileage),
    nextDueOn: Value(item.nextDueOn),
    enabled: Value(item.enabled),
    notes: Value(item.notes),
    catalogKey: Value(item.catalogKey),
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
    workshopName: row.workshopName,
    notes: row.notes,
    receiptLocalPath: row.receiptLocalPath,
    receiptMediaId: row.receiptMediaId,
    items: lines.map(serviceLineFromDrift).toList(),
    parts: parts.map(assignedPartFromDrift).toList(),
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
  return AssignedPart(
    id: row.id,
    partId: row.partId,
    name: row.name,
  );
}

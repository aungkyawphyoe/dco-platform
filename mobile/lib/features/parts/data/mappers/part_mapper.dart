import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/part.dart';

Part partFromDrift(PartRecord row) {
  return Part(
    id: row.id,
    userId: row.userId,
    vehicleId: row.vehicleId,
    name: row.name,
    brand: row.brand,
    partNumber: row.partNumber,
    notes: row.notes,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

PartRecordsCompanion partToCompanion(Part part) {
  return PartRecordsCompanion.insert(
    id: part.id,
    userId: part.userId,
    vehicleId: part.vehicleId,
    name: part.name,
    brand: Value(part.brand),
    partNumber: Value(part.partNumber),
    notes: Value(part.notes),
    updatedAt: part.updatedAt,
    createdAt: part.createdAt,
  );
}

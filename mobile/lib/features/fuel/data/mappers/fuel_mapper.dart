import '../../../../core/database/app_database.dart';
import '../../domain/entities/fuel_catalog_type.dart';
import '../../domain/entities/fuel_log.dart';

FuelCatalogType fuelCatalogTypeFromDrift(FuelTypeRecord row) {
  return FuelCatalogType(
    id: row.id,
    userId: row.userId,
    name: row.name,
    kind: FuelCatalogKind.parse(row.kind),
    unit: row.unit,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

FuelTypeRecordsCompanion fuelCatalogTypeToCompanion(FuelCatalogType type) {
  return FuelTypeRecordsCompanion.insert(
    id: type.id,
    userId: type.userId,
    name: type.name,
    kind: type.kind.storage,
    unit: type.unit,
    updatedAt: type.updatedAt,
    createdAt: type.createdAt,
  );
}

FuelLog fuelLogFromDrift(FuelLogRecord row) {
  return FuelLog(
    id: row.id,
    userId: row.userId,
    vehicleId: row.vehicleId,
    kind: FuelLogKind.parse(row.kind),
    fuelTypeId: row.fuelTypeId,
    fuelTypeName: row.fuelTypeName,
    unit: row.unit,
    loggedOn: row.loggedOn,
    amount: row.amount,
    cost: row.cost,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

FuelLogRecordsCompanion fuelLogToCompanion(FuelLog log) {
  return FuelLogRecordsCompanion.insert(
    id: log.id,
    userId: log.userId,
    vehicleId: log.vehicleId,
    kind: log.kind.storage,
    fuelTypeId: log.fuelTypeId,
    fuelTypeName: log.fuelTypeName,
    unit: log.unit,
    loggedOn: log.loggedOn,
    amount: log.amount,
    cost: log.cost,
    updatedAt: log.updatedAt,
    createdAt: log.createdAt,
  );
}

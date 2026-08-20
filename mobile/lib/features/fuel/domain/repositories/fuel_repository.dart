import '../entities/fuel_catalog_type.dart';
import '../entities/fuel_log.dart';

abstract class FuelRepository {
  Stream<List<FuelCatalogType>> watchFuelTypes(String userId, {FuelCatalogKind? kind});

  Future<FuelCatalogType?> getFuelType(String id);

  Future<void> ensureDefaultFuelTypes(String userId);

  Future<FuelCatalogType> addFuelType({
    required String userId,
    required FuelCatalogTypeDraft draft,
  });

  Future<FuelCatalogType> updateFuelType({
    required String userId,
    required String fuelTypeId,
    required FuelCatalogTypeDraft draft,
  });

  Stream<List<FuelLog>> watchLogs({
    required String vehicleId,
    required FuelLogKind kind,
  });

  Future<FuelLog?> getLog(String id);

  Future<FuelLog> addLog({
    required String userId,
    required String vehicleId,
    required FuelLogKind kind,
    required FuelLogDraft draft,
  });

  Future<FuelLog> updateLog({
    required String userId,
    required String logId,
    required FuelLogKind kind,
    required FuelLogDraft draft,
  });
}

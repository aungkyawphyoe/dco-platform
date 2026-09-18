import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/suggested_plan_item.dart';

abstract class MaintenanceCatalogRepository {
  /// Fetch catalog items from the server and cache them locally.
  Future<void> fetchAndCache(String vehicleId);

  /// Watch catalog items for a specific fuel type from local DB.
  Stream<List<SuggestedPlanItem>> watchByFuelType(FuelType fuelType);

  /// Get all cached catalog items.
  Future<List<SuggestedPlanItem>> getAll();
}

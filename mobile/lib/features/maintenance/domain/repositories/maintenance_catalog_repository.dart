import '../entities/suggested_plan_item.dart';

abstract class MaintenanceCatalogRepository {
  /// Refresh only this vehicle's account-scoped local cache. Throws on failure.
  Future<void> fetchAndCache(String vehicleId);

  /// Null means not cached; an empty list means a successful empty response.
  Stream<List<SuggestedPlanItem>?> watchForVehicle(String vehicleId);
}

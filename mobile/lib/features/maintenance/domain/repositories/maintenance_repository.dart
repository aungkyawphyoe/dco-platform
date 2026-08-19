import '../../../garage/domain/entities/vehicle.dart';
import '../entities/plan_item.dart';
import '../entities/service_record.dart';
import '../entities/suggested_plan_item.dart';

abstract class MaintenanceRepository {
  Stream<List<PlanItem>> watchPlan(String vehicleId);

  Stream<List<ServiceRecord>> watchHistory(String vehicleId);

  Future<PlanItem?> getPlanItem(String id);

  Future<ServiceRecord?> getServiceRecord(String id);

  Future<bool> hasPlan(String vehicleId);

  Future<void> ensureDefaultPlan({
    required String userId,
    required Vehicle vehicle,
  });

  Future<PlanItem> addPlanItem({
    required String userId,
    required Vehicle vehicle,
    required PlanItemDraft draft,
  });

  Future<PlanItem> updatePlanItem({
    required String userId,
    required Vehicle vehicle,
    required String planItemId,
    required PlanItemDraft draft,
  });

  Future<void> addSuggestedItem({
    required String userId,
    required Vehicle vehicle,
    required SuggestedPlanItem suggestion,
  });

  Future<ServiceRecord> registerService({
    required String userId,
    required Vehicle vehicle,
    required ServiceRecordDraft draft,
  });
}

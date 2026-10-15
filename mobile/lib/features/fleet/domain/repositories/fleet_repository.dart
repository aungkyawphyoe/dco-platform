import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/shift_mileage.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';

/// Server rejected the caller's organization role (HTTP 403). Presentation
/// maps this to the "no access" empty state — it must not inspect Dio.
class FleetAccessDenied implements Exception {
  const FleetAccessDenied();

  @override
  String toString() => 'Fleet access denied';
}

/// Online-first Fleet API access for the restricted driver surface. Fleet
/// management (members, inventory, assignments, analytics, warranty) lives on
/// the Fleet Portal and is not reachable from this app.
abstract class FleetRepository {
  // ── Entitlements ──
  Future<Entitlements> getEntitlements();

  // ── Work orders (driver) ──

  /// Create work order — `org_driver` only (assigned vehicle).
  Future<WorkOrder> createWorkOrder(
    String orgId, {
    required String vehicleId,
    required int odometerKm,
    required String issueType,
    required String description,
    required String urgency,
  });

  // ── Inspections (driver) ──
  Future<List<InspectionTemplate>> getInspectionTemplates(String orgId);

  /// Start inspection — driver (pre/post trip).
  Future<Inspection> startInspection(
    String orgId, {
    required String vehicleId,
    required String templateId,
    required String inspectionType,
  });

  /// Complete inspection with checklist results — driver.
  Future<Inspection> completeInspection(
    String orgId,
    String inspectionId, {
    required List<InspectionItemResult> items,
    String? notes,
  });

  // ── Shift mileage (driver) ──
  Future<List<ShiftMileage>> getShiftMileage(String orgId);
  Future<ShiftMileage> startShift(
    String orgId, {
    required String vehicleId,
    required int startOdometerKm,
  });
  Future<ShiftMileage> endShift(
    String orgId,
    String shiftId, {
    required int endOdometerKm,
  });

  // ── Org fuel logs (driver) ──
  Future<void> logOrgFuel(
    String orgId, {
    required String vehicleId,
    required String fuelTypeId,
    required String loggedOn,
    required double amount,
    required double cost,
    required int odometerKm,
  });

  // ── Driver surface ──
  Future<DriverMyVehicle> getDriverMyVehicle();
  Future<List<WorkOrder>> getDriverWorkOrders();
  Future<List<Inspection>> getDriverInspections();

  /// Assigned vehicle's maintenance plan — active assignment required.
  Future<List<DriverPlanItem>> getDriverPlanItems(String vehicleId);

  /// Driver adds a plan item (e.g. from the suggested list); idempotent by
  /// [id] (client UUID).
  Future<DriverPlanItem> addDriverPlanItem(
    String vehicleId, {
    required String id,
    required String name,
    int? intervalDays,
    double? intervalDistance,
    String? notes,
  });

  /// Suggested items from the vehicle's assigned template set (empty when
  /// no template is assigned).
  Future<List<DriverSuggestedPlanItem>> getDriverSuggestedPlanItems(
    String vehicleId,
  );
}

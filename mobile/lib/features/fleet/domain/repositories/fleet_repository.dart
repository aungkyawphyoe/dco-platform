import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_service_record.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';

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
  /// [issueType] `scheduled_service` = maintenance Report branch (then it
  /// shows in Maintenance history); other types are the standalone Report
  /// Issue flow (then it shows in the pushed Reports screen).
  Future<WorkOrder> createWorkOrder(
    String orgId, {
    required String vehicleId,
    required int odometerKm,
    required String issueType,
    required String description,
    required String urgency,
    String? planItemId,
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

  /// Assigned vehicle's service records (history), newest first —
  /// `GET /v1/drivers/vehicles/{vehicleId}/service-records`.
  Future<List<DriverServiceRecord>> getDriverServiceRecords(String vehicleId);

  /// Assigned vehicle's own fuel logs (fuel-only Expenses), newest first —
  /// `GET /v1/drivers/vehicles/{vehicleId}/fuel-logs`.
  Future<List<FuelLog>> getDriverFuelLogs(String vehicleId);

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

  /// Driver "Do myself" maintenance log — `POST /v1/drivers/vehicles/
  /// {vehicleId}/service-records`. Writes a service record directly
  /// (status is implicit Completed). [planItemId] links the log and advances
  /// the plan item's next due dates; when absent, [name] creates a free-text
  /// orphan record. Odometer must not decrease (server-enforced).
  Future<DriverServiceRecord> logDriverServiceRecord(
    String vehicleId, {
    required String id,
    required String servicedOn,
    required int odometerKm,
    required double totalCost,
    String? planItemId,
    String? name,
    String? notes,
  });

  /// Merged maintenance history: service records + work orders the driver
  /// reported as maintenance (`issueType == 'scheduled_service'`), newest
  /// first.
  Future<List<DriverHistoryEntry>> getDriverMaintenanceHistory(
    String vehicleId,
  );
}

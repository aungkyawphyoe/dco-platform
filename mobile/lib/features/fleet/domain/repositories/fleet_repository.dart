import 'package:dco_mobile/features/fleet/domain/entities/driver_assignment.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization_member.dart';
import 'package:dco_mobile/features/fleet/domain/entities/org_vehicle.dart';
import 'package:dco_mobile/features/fleet/domain/entities/shift_mileage.dart';
import 'package:dco_mobile/features/fleet/domain/entities/vehicle_cost.dart';
import 'package:dco_mobile/features/fleet/domain/entities/warranty_template.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';

/// Server rejected the caller's organization role (HTTP 403). Presentation
/// maps this to the "no access" empty state — it must not inspect Dio.
class FleetAccessDenied implements Exception {
  const FleetAccessDenied();

  @override
  String toString() => 'Fleet access denied';
}

/// Online-first Fleet API access (Dio-backed with local cache fallback for
/// navigation snapshots; list endpoints are online-only).
abstract class FleetRepository {
  // ── Entitlements / organization ──
  Future<Entitlements> getEntitlements();
  Future<MyOrganization> getMyOrganization();

  /// Locally persisted navigation mode (personal / fleet / driver).
  Future<FleetMode> getStoredMode();
  Future<void> setStoredMode(FleetMode mode);

  // ── Organization members ──
  Future<List<OrgMember>> getMembers(String orgId);

  /// Update member role — `org_admin` only.
  Future<void> updateMemberRole(String orgId, String userId, String role);

  /// Remove member — `org_admin` only.
  Future<void> removeMember(String orgId, String userId);

  // ── Organization vehicles ──
  Future<List<OrgVehicle>> getVehicles(String orgId);

  /// Add vehicle to org — `org_admin` / `org_manager`.
  Future<OrgVehicle> addVehicle(String orgId, OrgVehicleDraft draft);

  /// Transfer vehicle to buyer — `org_admin`, showroom lifecycle only.
  Future<VehicleTransferResult> transferVehicle(
    String orgId,
    String vehicleId,
    VehicleTransferDraft draft,
  );

  /// Lifecycle status transition — `org_admin` / `org_manager`.
  /// Server validates the transition against the lifecycle template.
  Future<OrgVehicle> updateVehicleStatus(
    String orgId,
    String vehicleId, {
    required String status,
    String? revenueLabel,
  });

  Future<VehicleImportResult> importVehiclesCsv(
    String orgId,
    List<int> bytes,
    String fileName,
  );

  Future<VehicleImportJob?> getImportJob(String orgId, String jobId);

  // ── Workshops ──
  Future<List<OrgWorkshop>> getWorkshops(String orgId);

  // ── Driver assignments ──
  Future<List<DriverAssignment>> getAssignments(String orgId);

  /// Assign vehicle to driver — `org_admin` / `org_manager`.
  Future<DriverAssignment> assignVehicle(
    String orgId,
    String vehicleId,
    String driverId,
  );

  /// Unassign — `org_admin` / `org_manager`.
  Future<void> unassignVehicle(String orgId, String assignmentId);

  // ── Work orders ──
  Future<List<WorkOrder>> getWorkOrders(String orgId);

  /// Create work order — `org_driver` only (assigned vehicle).
  Future<WorkOrder> createWorkOrder(
    String orgId, {
    required String vehicleId,
    required int odometerKm,
    required String issueType,
    required String description,
    required String urgency,
  });

  /// Update status — `org_admin` / `org_manager`.
  Future<WorkOrder> updateWorkOrder(
    String orgId,
    String workOrderId, {
    required String status,
    String? assignedTo,
    String? resolutionNotes,
  });

  // ── Inspections ──
  Future<List<Inspection>> getInspections(String orgId);
  Future<List<InspectionTemplate>> getInspectionTemplates(String orgId);

  /// Start inspection — driver (pre/post trip) or manager (`random`).
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

  // ── Shift mileage ──
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

  // ── Analytics / reports ──
  Future<FleetAnalytics> getFleetAnalytics(String orgId);
  Future<VehicleCost> getVehicleCost(String orgId, String vehicleId);
  Future<LemonReport> getLemons(String orgId);

  /// CSV export payload (raw CSV text) — `org_admin` / `org_manager`.
  Future<String> exportReportCsv(String orgId, String type);

  // ── Warranty templates ──
  Future<List<WarrantyTemplate>> getWarrantyTemplates(String orgId);
  Future<WarrantyTemplate> createWarrantyTemplate(
    String orgId, {
    required String name,
    required int durationYears,
    required int mileageLimitKm,
    List<String> coverageCategories = const [],
    String? exclusions,
    List<String> approvedWorkshopIds = const [],
  });
  Future<void> deleteWarrantyTemplate(String orgId, String templateId);

  // ── Driver surface ──
  Future<DriverMyVehicle> getDriverMyVehicle();
  Future<List<WorkOrder>> getDriverWorkOrders();
  Future<List<Inspection>> getDriverInspections();
}

class OrgVehicleDraft {
  const OrgVehicleDraft({
    required this.id,
    required this.name,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.vin,
    required this.fuelType,
    required this.mileage,
    required this.lifecycleTemplate,
    this.revenueLabel,
  });

  final String id;
  final String name;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String vin;
  final String fuelType;
  final int mileage;
  final String lifecycleTemplate;
  final String? revenueLabel;
}

class VehicleTransferDraft {
  const VehicleTransferDraft({
    required this.buyerEmail,
    required this.saleDate,
    required this.currentMileageKm,
    this.warrantyTemplateId,
  });

  final String buyerEmail;
  final String saleDate;
  final int currentMileageKm;
  final String? warrantyTemplateId;
}

class VehicleTransferResult {
  const VehicleTransferResult({
    required this.vehicleId,
    required this.buyerUserId,
    required this.transferredAt,
    required this.warrantyInstanceId,
    required this.status,
  });

  factory VehicleTransferResult.fromJson(Map<String, dynamic> json) {
    return VehicleTransferResult(
      vehicleId: json['vehicle_id'] as String? ?? '',
      buyerUserId: json['buyer_user_id'] as String? ?? '',
      transferredAt: json['transferred_at'] as String?,
      warrantyInstanceId: json['warranty_instance_id'] as String?,
      status: json['status'] as String? ?? 'sold',
    );
  }

  final String vehicleId;
  final String buyerUserId;
  final String? transferredAt;
  final String? warrantyInstanceId;
  final String status;
}

class VehicleImportResult {
  const VehicleImportResult({
    required this.jobId,
    required this.status,
    required this.totalRows,
  });

  factory VehicleImportResult.fromJson(Map<String, dynamic> json) {
    return VehicleImportResult(
      jobId: json['job_id'] as String,
      status: json['status'] as String? ?? 'processing',
      totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
    );
  }

  final String jobId;
  final String status;
  final int totalRows;
}

class VehicleImportJob {
  const VehicleImportJob({
    required this.jobId,
    required this.status,
    required this.totalRows,
    required this.successCount,
    required this.failCount,
  });

  factory VehicleImportJob.fromJson(Map<String, dynamic> json) {
    return VehicleImportJob(
      jobId: json['job_id'] as String? ?? '',
      status: json['status'] as String? ?? 'processing',
      totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
      successCount: (json['success_count'] as num?)?.toInt() ?? 0,
      failCount: (json['fail_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String jobId;
  final String status;
  final int totalRows;
  final int successCount;
  final int failCount;
}

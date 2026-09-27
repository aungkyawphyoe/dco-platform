import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dco_mobile/core/database/app_database.dart';
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
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';

/// Fleet API over Dio with an `AppMeta` JSON cache as offline fallback for
/// navigation snapshots (entitlements, organization, mode). List endpoints
/// are online-first without cache.
class FleetRepositoryImpl implements FleetRepository {
  FleetRepositoryImpl(this._dio, this._db, this._userId);

  final Dio _dio;
  final AppDatabase _db;
  final String? _userId;

  // ── Entitlements / organization ────────────────────────────────────

  @override
  Future<Entitlements> getEntitlements() async {
    try {
      final data = await _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/me/entitlements',
        );
        return response.data;
      });
      if (data == null) throw const FormatException('Empty entitlements');
      await _writeCache('entitlements', jsonEncode(data));
      return Entitlements.fromJson(data);
    } catch (e) {
      if (e is FleetAccessDenied) rethrow;
      final cached = await _readCache('entitlements');
      if (cached != null) return Entitlements.fromJson(cached);
      rethrow;
    }
  }

  @override
  Future<MyOrganization> getMyOrganization() async {
    try {
      final data = await _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/organizations/me',
        );
        return response.data;
      });
      if (data == null) throw const FormatException('Empty organization');
      await _writeCache('org_me', jsonEncode(data));
      return MyOrganization.fromJson(data);
    } catch (e) {
      if (e is FleetAccessDenied) rethrow;
      final cached = await _readCache('org_me');
      if (cached != null) return MyOrganization.fromJson(cached);
      rethrow;
    }
  }

  @override
  Future<FleetMode> getStoredMode() async =>
      FleetMode.fromStorage(await _readMode());

  @override
  Future<void> setStoredMode(FleetMode mode) => _writeCache('mode', mode.storage);

  // ── Members ────────────────────────────────────────────────────────

  @override
  Future<List<OrgMember>> getMembers(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/members',
    );
    return _items(response.data, OrgMember.fromJson);
  });

  @override
  Future<void> updateMemberRole(String orgId, String userId, String role) =>
      _call(
        () => _dio.patch(
          '/organizations/$orgId/members/$userId',
          data: {'role': role},
        ),
      );

  @override
  Future<void> removeMember(String orgId, String userId) => _call(
    () => _dio.patch(
      '/organizations/$orgId/members/$userId',
      data: {'remove': true},
    ),
  );

  // ── Vehicles ───────────────────────────────────────────────────────

  @override
  Future<List<OrgVehicle>> getVehicles(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/vehicles',
    );
    return _items(response.data, OrgVehicle.fromJson);
  });

  @override
  Future<OrgVehicle> addVehicle(String orgId, OrgVehicleDraft draft) =>
      _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/organizations/$orgId/vehicles',
          data: {
            'id': draft.id,
            'name': draft.name,
            'make': draft.make,
            'model': draft.model,
            'year': draft.year,
            'license_plate': draft.licensePlate,
            'vin': draft.vin,
            'fuel_type': draft.fuelType,
            'mileage': draft.mileage,
            'lifecycle_template': draft.lifecycleTemplate,
            'revenue_label': ?draft.revenueLabel,
          },
        );
        return OrgVehicle.fromJson(response.data!);
      });

  @override
  Future<VehicleTransferResult> transferVehicle(
    String orgId,
    String vehicleId,
    VehicleTransferDraft draft,
  ) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/vehicles/$vehicleId/transfer',
      data: {
        'buyer_email': draft.buyerEmail,
        'sale_date': draft.saleDate,
        'current_mileage_km': draft.currentMileageKm,
        'warranty_template_id': ?draft.warrantyTemplateId,
      },
    );
    return VehicleTransferResult.fromJson(response.data!);
  });

  @override
  Future<OrgVehicle> updateVehicleStatus(
    String orgId,
    String vehicleId, {
    required String status,
    String? revenueLabel,
  }) => _call(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/organizations/$orgId/vehicles/$vehicleId',
      data: {
        'status': status,
        'revenue_label': ?revenueLabel,
      },
    );
    return OrgVehicle.fromJson(response.data!);
  });

  @override
  Future<VehicleImportResult> importVehiclesCsv(
    String orgId,
    List<int> bytes,
    String fileName,
  ) => _call(() async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/vehicles/import',
      data: form,
    );
    return VehicleImportResult.fromJson(response.data!);
  });

  @override
  Future<VehicleImportJob?> getImportJob(String orgId, String jobId) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/organizations/$orgId/vehicles/import/$jobId',
        );
        return response.data == null
            ? null
            : VehicleImportJob.fromJson(response.data!);
      });

  // ── Workshops ──────────────────────────────────────────────────────

  @override
  Future<List<OrgWorkshop>> getWorkshops(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/workshops',
    );
    return _items(response.data, OrgWorkshop.fromJson);
  });

  // ── Assignments ────────────────────────────────────────────────────

  @override
  Future<List<DriverAssignment>> getAssignments(String orgId) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/organizations/$orgId/assignments',
        );
        return _items(response.data, DriverAssignment.fromJson);
      });

  @override
  Future<DriverAssignment> assignVehicle(
    String orgId,
    String vehicleId,
    String driverId,
  ) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/assignments',
      data: {'vehicle_id': vehicleId, 'driver_id': driverId},
    );
    return DriverAssignment.fromJson(response.data!);
  });

  @override
  Future<void> unassignVehicle(String orgId, String assignmentId) => _call(
    () => _dio.delete('/organizations/$orgId/assignments/$assignmentId'),
  );

  // ── Work orders ────────────────────────────────────────────────────

  @override
  Future<List<WorkOrder>> getWorkOrders(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/work-orders',
    );
    return _items(response.data, WorkOrder.fromJson);
  });

  @override
  Future<WorkOrder> createWorkOrder(
    String orgId, {
    required String vehicleId,
    required int odometerKm,
    required String issueType,
    required String description,
    required String urgency,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/work-orders',
      data: {
        'vehicle_id': vehicleId,
        'odometer_km': odometerKm,
        'issue_type': issueType,
        'description': description,
        'urgency': urgency,
      },
    );
    return WorkOrder.fromJson(response.data!);
  });

  @override
  Future<WorkOrder> updateWorkOrder(
    String orgId,
    String workOrderId, {
    required String status,
    String? assignedTo,
    String? resolutionNotes,
  }) => _call(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/organizations/$orgId/work-orders/$workOrderId',
      data: {
        'status': status,
        'assigned_to': ?assignedTo,
        'resolution_notes': ?resolutionNotes,
      },
    );
    return WorkOrder.fromJson(response.data!);
  });

  // ── Inspections ────────────────────────────────────────────────────

  @override
  Future<List<Inspection>> getInspections(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/inspections',
    );
    return _items(response.data, Inspection.fromJson);
  });

  @override
  Future<List<InspectionTemplate>> getInspectionTemplates(String orgId) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/organizations/$orgId/inspection-templates',
        );
        return _items(response.data, InspectionTemplate.fromJson);
      });

  @override
  Future<Inspection> startInspection(
    String orgId, {
    required String vehicleId,
    required String templateId,
    required String inspectionType,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/inspections',
      data: {
        'vehicle_id': vehicleId,
        'template_id': templateId,
        'inspection_type': inspectionType,
      },
    );
    return Inspection.fromJson(response.data!);
  });

  @override
  Future<Inspection> completeInspection(
    String orgId,
    String inspectionId, {
    required List<InspectionItemResult> items,
    String? notes,
  }) => _call(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/organizations/$orgId/inspections/$inspectionId',
      data: {
        'items': items.map((item) => item.toJson()).toList(),
        'notes': ?notes,
      },
    );
    return Inspection.fromJson(response.data!);
  });

  // ── Shift mileage ──────────────────────────────────────────────────

  @override
  Future<List<ShiftMileage>> getShiftMileage(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/shift-mileage',
    );
    return _items(response.data, ShiftMileage.fromJson);
  });

  @override
  Future<ShiftMileage> startShift(
    String orgId, {
    required String vehicleId,
    required int startOdometerKm,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/shift-mileage',
      data: {'vehicle_id': vehicleId, 'start_odometer_km': startOdometerKm},
    );
    return ShiftMileage.fromJson(response.data!);
  });

  @override
  Future<ShiftMileage> endShift(
    String orgId,
    String shiftId, {
    required int endOdometerKm,
  }) => _call(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/organizations/$orgId/shift-mileage/$shiftId',
      data: {'end_odometer_km': endOdometerKm},
    );
    return ShiftMileage.fromJson(response.data!);
  });

  // ── Org fuel logs ──────────────────────────────────────────────────

  @override
  Future<void> logOrgFuel(
    String orgId, {
    required String vehicleId,
    required String fuelTypeId,
    required String loggedOn,
    required double amount,
    required double cost,
    required int odometerKm,
  }) => _call(
    () => _dio.post(
      '/organizations/$orgId/fuel-logs',
      data: {
        'vehicle_id': vehicleId,
        'fuel_type_id': fuelTypeId,
        'logged_on': loggedOn,
        'amount': amount,
        'cost': cost,
        'odometer_km': odometerKm,
      },
    ),
  );

  // ── Analytics / reports ────────────────────────────────────────────

  @override
  Future<FleetAnalytics> getFleetAnalytics(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/analytics/fleet',
    );
    return FleetAnalytics.fromJson(response.data!);
  });

  @override
  Future<VehicleCost> getVehicleCost(String orgId, String vehicleId) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/organizations/$orgId/analytics/vehicle/$vehicleId',
        );
        return VehicleCost.fromJson(response.data!);
      });

  @override
  Future<LemonReport> getLemons(String orgId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$orgId/analytics/lemons',
    );
    return LemonReport.fromJson(response.data!);
  });

  @override
  Future<String> exportReportCsv(String orgId, String type) => _call(() async {
    final response = await _dio.get<String>(
      '/organizations/$orgId/reports/export',
      queryParameters: {'type': type},
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  });

  // ── Warranty templates ─────────────────────────────────────────────

  @override
  Future<List<WarrantyTemplate>> getWarrantyTemplates(String orgId) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/organizations/$orgId/warranty-templates',
        );
        return _items(response.data, WarrantyTemplate.fromJson);
      });

  @override
  Future<WarrantyTemplate> createWarrantyTemplate(
    String orgId, {
    required String name,
    required int durationYears,
    required int mileageLimitKm,
    List<String> coverageCategories = const [],
    String? exclusions,
    List<String> approvedWorkshopIds = const [],
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/warranty-templates',
      data: {
        'name': name,
        'duration_years': durationYears,
        'mileage_limit_km': mileageLimitKm,
        'coverage_categories': coverageCategories,
        'exclusions': ?exclusions,
        'approved_workshop_ids': approvedWorkshopIds,
      },
    );
    return WarrantyTemplate.fromJson(response.data!);
  });

  @override
  Future<void> deleteWarrantyTemplate(String orgId, String templateId) =>
      _call(
        () => _dio.delete(
          '/organizations/$orgId/warranty-templates/$templateId',
        ),
      );

  // ── Driver surface ─────────────────────────────────────────────────

  @override
  Future<DriverMyVehicle> getDriverMyVehicle() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/drivers/my-vehicle',
    );
    return DriverMyVehicle.fromJson(response.data!);
  });

  @override
  Future<List<WorkOrder>> getDriverWorkOrders() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/drivers/my-work-orders',
    );
    return _items(response.data, WorkOrder.fromJson);
  });

  @override
  Future<List<Inspection>> getDriverInspections() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/drivers/my-inspections',
    );
    return _items(response.data, Inspection.fromJson);
  });

  // ── Helpers ────────────────────────────────────────────────────────

  /// Maps HTTP 403 (org role rejected) to the domain-level
  /// [FleetAccessDenied] so presentation never touches Dio.
  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) throw const FleetAccessDenied();
      rethrow;
    }
  }

  List<T> _items<T>(
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = (data?['items'] as List?) ?? const [];
    return raw.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  String get _cachePrefix =>
      (_userId == null || _userId.isEmpty) ? 'fleet:none' : 'fleet:$_userId';

  Future<void> _writeCache(String name, String value) async {
    final key = '$_cachePrefix.$name';
    await _db
        .into(_db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion(key: drift.Value(key), value: drift.Value(value)),
        );
  }

  Future<Map<String, dynamic>?> _readCache(String name) async {
    final raw = await _readRaw(name);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<String?> _readMode() => _readRaw('mode');

  Future<String?> _readRaw(String name) async {
    final key = '$_cachePrefix.$name';
    final row =
        await (_db.select(_db.appMeta)..where((m) => m.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }
}

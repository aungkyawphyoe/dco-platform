import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/shift_mileage.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';

/// Driver-surface Fleet API over Dio with an `AppMeta` JSON cache as offline
/// fallback for navigation snapshots (entitlements only). List endpoints are
/// online-first without cache. Fleet management is portal-only.
class FleetRepositoryImpl implements FleetRepository {
  FleetRepositoryImpl(this._dio, this._db, this._userId);

  final Dio _dio;
  final AppDatabase _db;
  final String? _userId;

  // ── Entitlements ───────────────────────────────────────────────────

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

  // ── Work orders (driver) ───────────────────────────────────────────

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

  // ── Inspections (driver) ───────────────────────────────────────────

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

  // ── Shift mileage (driver) ─────────────────────────────────────────

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

  // ── Org fuel logs (driver) ─────────────────────────────────────────

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

  @override
  Future<List<DriverPlanItem>> getDriverPlanItems(String vehicleId) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/drivers/vehicles/$vehicleId/plan-items',
        );
        return _items(response.data, DriverPlanItem.fromJson);
      });

  @override
  Future<DriverPlanItem> addDriverPlanItem(
    String vehicleId, {
    required String id,
    required String name,
    int? intervalDays,
    double? intervalDistance,
    String? notes,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/drivers/vehicles/$vehicleId/plan-items',
      data: {
        'id': id,
        'name': name,
        'interval_days': ?intervalDays,
        'interval_distance': ?intervalDistance,
        'notes': ?notes,
      },
    );
    return DriverPlanItem.fromJson(response.data!);
  });

  @override
  Future<List<DriverSuggestedPlanItem>> getDriverSuggestedPlanItems(
    String vehicleId,
  ) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/drivers/vehicles/$vehicleId/suggested-plan-items',
    );
    return _items(response.data, DriverSuggestedPlanItem.fromJson);
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

  Future<String?> _readRaw(String name) async {
    final key = '$_cachePrefix.$name';
    final row =
        await (_db.select(_db.appMeta)..where((m) => m.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }
}

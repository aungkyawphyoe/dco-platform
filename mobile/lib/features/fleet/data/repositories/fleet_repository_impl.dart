import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_service_record.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';

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
    String? planItemId,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations/$orgId/work-orders',
      data: {
        'vehicle_id': vehicleId,
        'odometer_km': odometerKm,
        'issue_type': issueType,
        'description': description,
        'urgency': urgency,
        'plan_item_id': ?planItemId,
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

  // ── Driver "Do myself" maintenance + history ───────────────────────

  @override
  Future<DriverServiceRecord> logDriverServiceRecord(
    String vehicleId, {
    required String id,
    required String servicedOn,
    required int odometerKm,
    required double totalCost,
    String? planItemId,
    String? name,
    String? notes,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/drivers/vehicles/$vehicleId/service-records',
      data: {
        'id': id,
        'serviced_on': servicedOn,
        'odometer_km': odometerKm,
        'total_cost': totalCost,
        'plan_item_id': ?planItemId,
        'name': ?name,
        'notes': ?notes,
      },
    );
    return DriverServiceRecord.fromJson(response.data!);
  });

  @override
  Future<List<DriverHistoryEntry>> getDriverMaintenanceHistory(
    String vehicleId,
  ) => _call(() async {
    // Service records (Do myself + portal completions) — driver-scoped read
    // of their assigned vehicle.
    final recordsResponse = await _dio.get<Map<String, dynamic>>(
      '/drivers/vehicles/$vehicleId/service-records',
    );
    final records = _items(
      recordsResponse.data,
      (json) => DriverHistoryEntry.serviceRecord(
        id: json['id'] as String,
        servicedOn: DateTime.parse(json['serviced_on'] as String),
        odometer: (json['odometer'] as num).toDouble(),
        totalCost: (json['total_cost'] as num).toDouble(),
        title: ((json['items'] as List?) ?? const [])
            .map((e) => e['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .join(', '),
        notes: json['notes'] as String?,
      ),
    );

    // Maintenance-branch work orders (Report route) — already driver-scoped.
    final workOrdersResponse = await _dio.get<Map<String, dynamic>>(
      '/drivers/my-work-orders',
    );
    final workOrders = _items(
      workOrdersResponse.data,
      WorkOrder.fromJson,
    ).where((wo) => wo.issueType == 'scheduled_service');

    return [...records, ...workOrders.map(
      (wo) => DriverHistoryEntry.workOrder(
        id: wo.id,
        servicedOn: DateTime.tryParse(wo.reportedAt ?? '') ?? DateTime.now(),
        odometer: wo.odometerKm.toDouble(),
        title: wo.description,
        workOrderStatus: wo.status,
      ),
    )]..sort((a, b) => b.servicedOn.compareTo(a.servicedOn));
  });

  @override
  Future<List<DriverServiceRecord>> getDriverServiceRecords(
    String vehicleId,
  ) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/drivers/vehicles/$vehicleId/service-records',
    );
    return _items(response.data, DriverServiceRecord.fromJson);
  });

  @override
  Future<List<FuelLog>> getDriverFuelLogs(String vehicleId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/drivers/vehicles/$vehicleId/fuel-logs',
    );
    return _items(response.data, _orgFuelLogFromJson);
  });

  // ── Helpers ────────────────────────────────────────────────────────

  /// Org fuel-log payload → [FuelLog]. Mirrors `fuelLogFromDrift` but the API
  /// sends dates as `yyyy-MM-dd` and omits the audit timestamps.
  static FuelLog _orgFuelLogFromJson(Map<String, dynamic> json) {
    return FuelLog(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      kind: FuelLogKind.parse(json['kind'] as String? ?? 'refuel'),
      fuelTypeId: json['fuel_type_id'] as String? ?? '',
      fuelTypeName: json['fuel_type_name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      loggedOn: DateTime.parse(json['logged_on'] as String),
      amount: (json['amount'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
      odometer: (json['odometer_km'] as num?)?.toDouble(),
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

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

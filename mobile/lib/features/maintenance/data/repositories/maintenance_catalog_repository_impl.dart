import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../garage/domain/entities/vehicle.dart';
import '../../domain/entities/suggested_plan_item.dart';
import '../../domain/repositories/maintenance_catalog_repository.dart';

// Public constructor names keep the database and HTTP client private.
// ignore_for_file: prefer_initializing_formals

class MaintenanceCatalogRepositoryImpl implements MaintenanceCatalogRepository {
  MaintenanceCatalogRepositoryImpl({
    required AppDatabase db,
    required Dio dio,
    required this.userId,
  }) : _db = db,
       _dio = dio;

  final AppDatabase _db;
  final Dio _dio;
  final String userId;
  final _requests = <String, int>{};

  // Versioned cache intentionally ignores the legacy global fuel-type table.
  String _key(String vehicleId) =>
      'maintenance_catalog.v2:${jsonEncode([userId, vehicleId])}';

  @override
  Future<void> fetchAndCache(String vehicleId) async {
    if (userId.isEmpty || vehicleId.isEmpty) return;
    final generation = (_requests[vehicleId] ?? 0) + 1;
    _requests[vehicleId] = generation;
    final response = await _dio.get<Map<String, dynamic>>(
      '/vehicles/$vehicleId/suggested-plan-items',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException('Missing maintenance catalog items');
    }
    // Validate before replacing a usable offline cache.
    _decode(items);
    if (_requests[vehicleId] != generation) return;
    await _db
        .into(_db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion(
            key: Value(_key(vehicleId)),
            value: Value(jsonEncode(items)),
          ),
        );
  }

  @override
  Stream<List<SuggestedPlanItem>?> watchForVehicle(String vehicleId) =>
      (_db.select(_db.appMeta)..where((row) => row.key.equals(_key(vehicleId))))
          .watchSingleOrNull()
          .map((row) {
            if (row?.value == null) return null;
            return _decode(jsonDecode(row!.value!) as List);
          });

  List<SuggestedPlanItem> _decode(List items) => items
      .map(
        (item) => SuggestedPlanItem(
          catalogKey: item['catalog_key'] as String,
          name: item['name'] as String,
          intervalDays: item['interval_days'] as int?,
          intervalDistance: (item['interval_distance'] as num?)?.toDouble(),
          fuelTypes: {
            switch (item['fuel_type']) {
              'electric' => FuelType.electric,
              'hybrid_plugin' => FuelType.hybridPlugin,
              _ => FuelType.petrol,
            },
          },
        ),
      )
      .toList();
}

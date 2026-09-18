import 'dart:convert';

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/suggested_plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/repositories/maintenance_catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

class MaintenanceCatalogRepositoryImpl implements MaintenanceCatalogRepository {
  MaintenanceCatalogRepositoryImpl({
    required AppDatabase db,
    required Dio dio,
  })  : _db = db,
        _dio = dio;

  final AppDatabase _db;
  final Dio _dio;

  @override
  Future<void> fetchAndCache(String vehicleId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/suggested-plan-items',
      );
      final data = response.data;
      if (data == null) return;

      final items = (data['items'] as List<dynamic>?) ?? [];
      final records = items.map((item) {
        final fuelTypes = (item['fuel_type'] as String?) ?? 'petrol';
        return MaintenanceCatalogRecordsCompanion(
          id: Value(item['catalog_key'] as String),
          catalogKey: Value(item['catalog_key'] as String),
          name: Value(item['name'] as String),
          intervalDays: Value(item['interval_days'] as int?),
          intervalDistance: Value(
            item['interval_distance'] != null
                ? (item['interval_distance'] as num).toDouble()
                : null,
          ),
          fuelTypes: Value(jsonEncode([fuelTypes])),
          sortOrder: const Value(0),
          enabled: const Value(true),
          updatedAt: Value(DateTime.now().toUtc()),
          createdAt: Value(DateTime.now().toUtc()),
        );
      }).toList();

      await _db.transaction(() async {
        await _db.delete(_db.maintenanceCatalogRecords).go();
        for (final record in records) {
          await _db.into(_db.maintenanceCatalogRecords).insert(record);
        }
      });
    } on DioException {
      // Silently fail — catalog is best-effort, fallback to empty list
    }
  }

  @override
  Stream<List<SuggestedPlanItem>> watchByFuelType(FuelType fuelType) {
    return _db
        .select(_db.maintenanceCatalogRecords)
        .watch()
        .map((rows) {
      return rows
          .where((row) {
        final fuelTypes = _parseFuelTypes(row.fuelTypes);
        return fuelTypes.contains(_fuelTypeToString(fuelType));
      })
          .map((row) {
        return SuggestedPlanItem(
          catalogKey: row.catalogKey,
          name: row.name,
          intervalDays: row.intervalDays,
          intervalDistance: row.intervalDistance,
          fuelTypes: _parseFuelTypes(row.fuelTypes)
              .map(_stringToFuelType)
              .toSet(),
        );
      }).toList();
    });
  }

  @override
  Future<List<SuggestedPlanItem>> getAll() async {
    final rows = await _db.select(_db.maintenanceCatalogRecords).get();
    return rows.map((row) {
      return SuggestedPlanItem(
        catalogKey: row.catalogKey,
        name: row.name,
        intervalDays: row.intervalDays,
        intervalDistance: row.intervalDistance,
        fuelTypes: _parseFuelTypes(row.fuelTypes)
            .map(_stringToFuelType)
            .toSet(),
      );
    }).toList();
  }

  List<String> _parseFuelTypes(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  String _fuelTypeToString(FuelType type) {
    switch (type) {
      case FuelType.petrol:
        return 'petrol';
      case FuelType.electric:
        return 'electric';
      case FuelType.hybridPlugin:
        return 'hybrid_plugin';
    }
  }

  FuelType _stringToFuelType(String value) {
    switch (value) {
      case 'electric':
        return FuelType.electric;
      case 'hybrid_plugin':
        return FuelType.hybridPlugin;
      default:
        return FuelType.petrol;
    }
  }
}

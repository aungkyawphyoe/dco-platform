import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/handover_receipt.dart';
import '../../domain/entities/vehicle_warranty.dart';
import '../../domain/repositories/handover_repository.dart';
import '../mappers/handover_mapper.dart';

class HandoverRepositoryImpl implements HandoverRepository {
  HandoverRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<VehicleWarranty?> watchWarranty(String vehicleId) {
    if (vehicleId.isEmpty) return Stream.value(null);
    final query = _db.select(_db.warrantyRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
      ..limit(1);
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : warrantyFromDrift(row),
    );
  }

  @override
  Stream<HandoverReceipt?> watchReceipt(String vehicleId) {
    if (vehicleId.isEmpty) return Stream.value(null);
    final query = _db.select(_db.handoverReceiptRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([
        (row) => OrderingTerm.desc(row.completedAt),
        (row) => OrderingTerm.desc(row.createdAt),
      ])
      ..limit(1);
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : receiptFromDrift(row),
    );
  }

  @override
  Future<VehicleWarranty?> getWarranty(String vehicleId) async {
    final query = _db.select(_db.warrantyRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : warrantyFromDrift(row);
  }

  @override
  Future<HandoverReceipt?> getReceipt(String vehicleId) async {
    final query = _db.select(_db.handoverReceiptRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([
        (row) => OrderingTerm.desc(row.completedAt),
        (row) => OrderingTerm.desc(row.createdAt),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : receiptFromDrift(row);
  }
}

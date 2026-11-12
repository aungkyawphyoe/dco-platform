import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/handover_receipt.dart';
import '../../domain/entities/vehicle_warranty.dart';

VehicleWarranty warrantyFromDrift(WarrantyRecord row) {
  return VehicleWarranty(
    id: row.id,
    vehicleId: row.vehicleId,
    saleDate: row.saleDate,
    saleMileageKm: row.saleMileageKm,
    status: row.status,
    terms: _map(row.termsJson),
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

HandoverReceipt receiptFromDrift(HandoverReceiptRecord row) {
  return HandoverReceipt(
    id: row.id,
    vehicleId: row.vehicleId,
    buyerUserId: row.buyerUserId,
    transferredVehicleId: row.transferredVehicleId,
    saleDate: row.saleDate,
    currentMileageKm: row.currentMileageKm,
    planItemIds: _list(row.planItemIdsJson),
    warrantyInstanceId: row.warrantyInstanceId,
    status: row.status,
    completedAt: row.completedAt,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

Map<String, dynamic> _map(String value) {
  try {
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}

List<String> _list(String value) {
  try {
    final decoded = jsonDecode(value);
    return decoded is List
        ? decoded.whereType<String>().where((id) => id.isNotEmpty).toList()
        : const [];
  } on FormatException {
    return const [];
  }
}

import '../entities/handover_receipt.dart';
import '../entities/vehicle_warranty.dart';

abstract class HandoverRepository {
  Stream<VehicleWarranty?> watchWarranty(String vehicleId);

  Stream<HandoverReceipt?> watchReceipt(String vehicleId);

  Future<VehicleWarranty?> getWarranty(String vehicleId);

  Future<HandoverReceipt?> getReceipt(String vehicleId);
}

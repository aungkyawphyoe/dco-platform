/// Evidence of what a buyer received when a showroom vehicle moved to their
/// personal account. The receipt is read-only and never implies showroom
/// history or access to the seller's records.
class HandoverReceipt {
  const HandoverReceipt({
    required this.id,
    required this.vehicleId,
    required this.buyerUserId,
    required this.planItemIds,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
    this.transferredVehicleId,
    this.saleDate,
    this.currentMileageKm,
    this.warrantyInstanceId,
    this.completedAt,
  });

  final String id;
  final String vehicleId;
  final String buyerUserId;
  final String? transferredVehicleId;
  final DateTime? saleDate;
  final double? currentMileageKm;
  final List<String> planItemIds;
  final String? warrantyInstanceId;
  final String status;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final DateTime createdAt;
}

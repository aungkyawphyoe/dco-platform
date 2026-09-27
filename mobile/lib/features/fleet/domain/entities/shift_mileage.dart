class ShiftMileage {
  const ShiftMileage({
    required this.id,
    required this.orgId,
    required this.vehicleId,
    required this.driverId,
    required this.startOdometerKm,
    required this.endOdometerKm,
    required this.startAt,
    required this.endAt,
    required this.kmDriven,
    required this.createdAt,
  });

  factory ShiftMileage.fromJson(Map<String, dynamic> json) {
    return ShiftMileage(
      id: json['id'] as String,
      orgId: json['org_id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      startOdometerKm: (json['start_odometer_km'] as num?)?.toInt() ?? 0,
      endOdometerKm: (json['end_odometer_km'] as num?)?.toInt(),
      startAt: json['start_at'] as String?,
      endAt: json['end_at'] as String?,
      kmDriven: (json['km_driven'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
    );
  }

  final String id;
  final String orgId;
  final String vehicleId;
  final String driverId;
  final int startOdometerKm;
  final int? endOdometerKm;
  final String? startAt;
  final String? endAt;
  final int? kmDriven;
  final String? createdAt;

  bool get isActive => endAt == null;
}

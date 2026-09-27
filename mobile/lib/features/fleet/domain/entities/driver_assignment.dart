class DriverAssignment {
  const DriverAssignment({
    required this.id,
    required this.orgId,
    required this.vehicleId,
    required this.driverId,
    required this.assignedBy,
    required this.assignedAt,
    required this.unassignedAt,
    required this.status,
  });

  factory DriverAssignment.fromJson(Map<String, dynamic> json) {
    return DriverAssignment(
      id: json['id'] as String,
      orgId: json['org_id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      assignedBy: json['assigned_by'] as String?,
      assignedAt: json['assigned_at'] as String?,
      unassignedAt: json['unassigned_at'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String orgId;
  final String vehicleId;
  final String driverId;
  final String? assignedBy;
  final String? assignedAt;
  final String? unassignedAt;
  final String status;

  bool get isActive => status == 'active';
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.orgId,
    required this.vehicleId,
    required this.reportedBy,
    required this.reportedAt,
    required this.odometerKm,
    required this.issueType,
    required this.description,
    required this.urgency,
    required this.photos,
    required this.status,
    required this.assignedTo,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      id: json['id'] as String,
      orgId: json['org_id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      reportedBy: json['reported_by'] as String? ?? '',
      reportedAt: json['reported_at'] as String?,
      odometerKm: (json['odometer_km'] as num?)?.toInt() ?? 0,
      issueType: json['issue_type'] as String? ?? 'other',
      description: json['description'] as String? ?? '',
      urgency: json['urgency'] as String? ?? 'medium',
      photos: ((json['photos'] as List?) ?? const []).cast<String>(),
      status: json['status'] as String? ?? 'reported',
      assignedTo: json['assigned_to'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String id;
  final String orgId;
  final String vehicleId;
  final String reportedBy;
  final String? reportedAt;
  final int odometerKm;
  final String issueType;
  final String description;
  final String urgency;
  final List<String> photos;

  /// `reported` | `in_progress` | `completed`.
  final String status;
  final String? assignedTo;
  final String? resolvedBy;
  final String? resolvedAt;
  final String? resolutionNotes;
  final String? createdAt;
  final String? updatedAt;

  bool get isOpen => status != 'completed';
}

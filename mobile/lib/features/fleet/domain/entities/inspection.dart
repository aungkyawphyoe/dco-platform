class InspectionTemplateItem {
  const InspectionTemplateItem({required this.itemName, required this.required});

  factory InspectionTemplateItem.fromJson(Map<String, dynamic> json) {
    return InspectionTemplateItem(
      itemName: json['item_name'] as String,
      required: json['required'] as bool? ?? true,
    );
  }

  final String itemName;
  final bool required;
}

class InspectionTemplate {
  const InspectionTemplate({
    required this.id,
    required this.orgId,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InspectionTemplate.fromJson(Map<String, dynamic> json) {
    return InspectionTemplate(
      id: json['id'] as String,
      orgId: json['org_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      items: ((json['items'] as List?) ?? const [])
          .map((e) => InspectionTemplateItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String id;
  final String orgId;
  final String name;
  final List<InspectionTemplateItem> items;
  final String? createdAt;
  final String? updatedAt;
}

class InspectionItemResult {
  const InspectionItemResult({
    required this.itemName,
    required this.result,
    required this.photoMediaId,
    required this.notes,
    required this.required,
  });

  factory InspectionItemResult.fromJson(Map<String, dynamic> json) {
    return InspectionItemResult(
      itemName: json['item_name'] as String,
      result: json['result'] as String? ?? 'ok',
      photoMediaId: json['photo_media_id'] as String?,
      notes: json['notes'] as String?,
      required: json['required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_name': itemName,
        'result': result,
        if (photoMediaId != null) 'photo_media_id': photoMediaId,
        if (notes != null) 'notes': notes,
      };

  final String itemName;

  /// `ok` | `not_ok`.
  final String result;
  final String? photoMediaId;
  final String? notes;
  final bool required;
}

class Inspection {
  const Inspection({
    required this.id,
    required this.orgId,
    required this.vehicleId,
    required this.driverId,
    required this.templateId,
    required this.inspectionType,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.items,
    required this.notes,
    required this.createdAt,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      orgId: json['org_id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      inspectionType: json['inspection_type'] as String? ?? 'pre_trip',
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      status: json['status'] as String? ?? 'in_progress',
      items: ((json['items'] as List?) ?? const [])
          .map((e) => InspectionItemResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  final String id;
  final String orgId;
  final String vehicleId;
  final String driverId;
  final String templateId;

  /// `pre_trip` | `post_trip` | `random`.
  final String inspectionType;
  final String? startedAt;
  final String? completedAt;

  /// `in_progress` | `completed` | `failed`.
  final String status;
  final List<InspectionItemResult> items;
  final String? notes;
  final String? createdAt;
}

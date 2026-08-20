class ServiceLine {
  const ServiceLine({
    required this.id,
    required this.name,
    this.planItemId,
    this.lineCost,
  });

  final String id;
  final String? planItemId;
  final String name;
  final double? lineCost;

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'plan_item_id': planItemId,
    'name': name,
    'line_cost': lineCost,
  };
}

class AssignedPart {
  const AssignedPart({
    required this.id,
    required this.partId,
    required this.name,
  });

  final String id;
  final String partId;
  final String name;

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'part_id': partId,
    'name': name,
  };
}

class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.servicedOn,
    required this.odometer,
    required this.totalCost,
    required this.items,
    required this.updatedAt,
    required this.createdAt,
    this.workshopName,
    this.notes,
    this.receiptLocalPath,
    this.receiptMediaId,
    this.parts = const [],
  });

  final String id;
  final String vehicleId;
  final String title;
  final DateTime servicedOn;
  final double odometer;
  final double totalCost;
  final String? workshopName;
  final String? notes;
  final String? receiptLocalPath;
  final String? receiptMediaId;
  final List<ServiceLine> items;
  final List<AssignedPart> parts;
  final DateTime updatedAt;
  final DateTime createdAt;

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'serviced_on': servicedOn.toIso8601String().split('T').first,
    'odometer': odometer,
    'total_cost': totalCost,
    'workshop_name': workshopName,
    'notes': notes,
    'title': title,
    'receipt_media_id': receiptMediaId,
    'items': items.map((item) => item.toWriteJson()).toList(),
    'parts': parts.map((part) => part.toWriteJson()).toList(),
  };
}

class ServiceLineDraft {
  const ServiceLineDraft({
    required this.name,
    this.planItemId,
    this.lineCost,
  });

  final String name;
  final String? planItemId;
  final double? lineCost;
}

class AssignedPartDraft {
  const AssignedPartDraft({
    required this.partId,
    required this.name,
  });

  final String partId;
  final String name;
}

class ServiceRecordDraft {
  const ServiceRecordDraft({
    required this.servicedOn,
    required this.odometer,
    required this.totalCost,
    required this.items,
    this.title,
    this.workshopName,
    this.notes,
    this.parts = const [],
  });

  final String? title;
  final DateTime servicedOn;
  final double odometer;
  final double totalCost;
  final String? workshopName;
  final String? notes;
  final List<ServiceLineDraft> items;
  final List<AssignedPartDraft> parts;
}

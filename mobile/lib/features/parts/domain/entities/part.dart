class Part {
  const Part({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.name,
    required this.updatedAt,
    required this.createdAt,
    this.brand,
    this.partNumber,
    this.notes,
  });

  final String id;
  final String userId;
  final String vehicleId;
  final String name;
  final String? brand;
  final String? partNumber;
  final String? notes;
  final DateTime updatedAt;
  final DateTime createdAt;

  String? get detailLine {
    final bits = [brand, partNumber].whereType<String>().where((value) => value.isNotEmpty);
    if (bits.isEmpty) return null;
    return bits.join(' · ');
  }

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'name': name,
    'brand': brand,
    'part_number': partNumber,
    'notes': notes,
  };
}

class PartDraft {
  const PartDraft({
    required this.name,
    this.brand,
    this.partNumber,
    this.notes,
  });

  final String name;
  final String? brand;
  final String? partNumber;
  final String? notes;
}

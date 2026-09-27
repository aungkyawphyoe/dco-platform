/// Organization vehicle: `publicVehicle` fields plus org lifecycle data.
class OrgVehicle {
  const OrgVehicle({
    required this.id,
    required this.name,
    required this.nickname,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.vin,
    required this.color,
    required this.fuelType,
    required this.mileage,
    required this.mileageUnit,
    required this.photoMediaId,
    required this.archived,
    required this.lifecycleTemplate,
    required this.status,
    required this.revenueLabel,
    required this.assignedDriverId,
    required this.addedAt,
  });

  factory OrgVehicle.fromJson(Map<String, dynamic> json) {
    return OrgVehicle(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nickname: json['nickname'] as String?,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      licensePlate: json['license_plate'] as String? ?? '',
      vin: json['vin'] as String?,
      color: json['color'] as String?,
      fuelType: json['fuel_type'] as String? ?? 'petrol',
      mileage: (json['mileage'] as num?)?.toInt() ?? 0,
      mileageUnit: json['mileage_unit'] as String? ?? 'km',
      photoMediaId: json['photo_media_id'] as String?,
      archived: json['archived'] as bool? ?? false,
      lifecycleTemplate: json['lifecycle_template'] as String? ?? 'showroom',
      status: json['status'] as String? ?? 'available',
      revenueLabel: json['revenue_label'] as String?,
      assignedDriverId: json['assigned_driver_id'] as String?,
      addedAt: json['added_at'] as String?,
    );
  }

  final String id;
  final String name;
  final String? nickname;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final String fuelType;
  final int mileage;
  final String mileageUnit;
  final String? photoMediaId;
  final bool archived;

  /// `showroom` | `taxi_fleet` | `rental` | `commercial`.
  final String lifecycleTemplate;

  /// Free-form, template-specific (e.g. `inventory`, `listed`, `leased`).
  final String status;
  final String? revenueLabel;
  final String? assignedDriverId;
  final String? addedAt;

  String get displayName =>
      nickname != null && nickname!.trim().isNotEmpty ? nickname!.trim() : name;
}

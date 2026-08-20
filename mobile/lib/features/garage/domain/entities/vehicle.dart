import 'package:dco_mobile/core/units/mileage_unit.dart';

export 'package:dco_mobile/core/units/mileage_unit.dart';

enum FuelType {
  petrol,
  electric,
  hybridPlugin;

  String get storage => switch (this) {
    FuelType.petrol => 'petrol',
    FuelType.electric => 'electric',
    FuelType.hybridPlugin => 'hybrid_plugin',
  };

  String get label => switch (this) {
    FuelType.petrol => 'Petrol',
    FuelType.electric => 'Electric',
    FuelType.hybridPlugin => 'Hybrid plugin',
  };

  static FuelType parse(String value) {
    return FuelType.values.firstWhere(
      (type) => type.storage == value || type.name == value,
      orElse: () => throw FormatException('Unknown fuel type: $value'),
    );
  }
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.fuelType,
    required this.mileage,
    required this.mileageUnit,
    required this.archived,
    required this.updatedAt,
    required this.createdAt,
    this.nickname,
    this.vin,
    this.color,
    this.purchaseDate,
    this.purchasePrice,
    this.photoLocalPath,
    this.photoMediaId,
    this.archivedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? nickname;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final FuelType fuelType;
  final double mileage;
  final MileageUnit mileageUnit;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? photoLocalPath;
  final String? photoMediaId;
  final bool archived;
  final DateTime? archivedAt;
  final DateTime updatedAt;
  final DateTime createdAt;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return name;
  }

  String get yearMakeModel => '$year $make $model';

  /// Payload shape matches OpenAPI `VehicleWrite` for later sync push.
  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'name': name,
    'nickname': nickname,
    'make': make,
    'model': model,
    'year': year,
    'license_plate': licensePlate,
    'vin': vin,
    'color': color,
    'fuel_type': fuelType.storage,
    'mileage': mileage,
    'mileage_unit': mileageUnit.name,
    'purchase_date': purchaseDate?.toIso8601String().split('T').first,
    'purchase_price': purchasePrice,
    'photo_media_id': photoMediaId,
  };
}

class VehicleDraft {
  const VehicleDraft({
    required this.name,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.fuelType,
    required this.mileage,
    this.mileageUnit = MileageUnit.mi,
    this.nickname,
    this.vin,
    this.color,
    this.purchaseDate,
    this.purchasePrice,
    this.photoLocalPath,
  });

  final String name;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final FuelType fuelType;
  final double mileage;
  final MileageUnit mileageUnit;
  final String? nickname;
  final String? vin;
  final String? color;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? photoLocalPath;
}

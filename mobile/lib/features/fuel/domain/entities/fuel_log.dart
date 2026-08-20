import 'fuel_catalog_type.dart';

enum FuelLogKind {
  refuel,
  charge;

  String get storage => name;

  String get label => switch (this) {
    FuelLogKind.refuel => 'Refuel',
    FuelLogKind.charge => 'Charge',
  };

  String get addLabel => switch (this) {
    FuelLogKind.refuel => 'Add Refuel',
    FuelLogKind.charge => 'Add Charge',
  };

  String get editLabel => switch (this) {
    FuelLogKind.refuel => 'Edit Refuel',
    FuelLogKind.charge => 'Edit Charge',
  };

  FuelCatalogKind get catalogKind => switch (this) {
    FuelLogKind.refuel => FuelCatalogKind.liquid,
    FuelLogKind.charge => FuelCatalogKind.electric,
  };

  static FuelLogKind parse(String value) {
    return FuelLogKind.values.firstWhere(
      (kind) => kind.storage == value || kind.name == value,
      orElse: () => throw FormatException('Unknown fuel log kind: $value'),
    );
  }

  static FuelLogKind forVehicleFuelType(String storage) {
    return storage == 'electric' ? FuelLogKind.charge : FuelLogKind.refuel;
  }
}

class FuelLog {
  const FuelLog({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.kind,
    required this.fuelTypeId,
    required this.fuelTypeName,
    required this.unit,
    required this.loggedOn,
    required this.amount,
    required this.cost,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String vehicleId;
  final FuelLogKind kind;
  final String fuelTypeId;
  final String fuelTypeName;
  final String unit;
  final DateTime loggedOn;
  final double amount;
  final double cost;
  final DateTime updatedAt;
  final DateTime createdAt;

  String get amountLabel {
    final value = amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return '$value $unit';
  }

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'kind': kind.storage,
    'fuel_type_id': fuelTypeId,
    'fuel_type_name': fuelTypeName,
    'unit': unit,
    'logged_on': loggedOn.toIso8601String(),
    'amount': amount,
    'cost': cost,
  };
}

class FuelLogDraft {
  const FuelLogDraft({
    required this.loggedOn,
    required this.fuelTypeId,
    required this.amount,
    required this.cost,
  });

  final DateTime loggedOn;
  final String fuelTypeId;
  final double amount;
  final double cost;
}

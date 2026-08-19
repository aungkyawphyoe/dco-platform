import '../../../garage/domain/entities/vehicle.dart';

class SuggestedPlanItem {
  const SuggestedPlanItem({
    required this.catalogKey,
    required this.name,
    required this.fuelTypes,
    this.intervalDays,
    this.intervalDistance,
  });

  final String catalogKey;
  final String name;
  final int? intervalDays;
  final double? intervalDistance;
  final Set<FuelType> fuelTypes;

  bool get recurring =>
      (intervalDays != null && intervalDays! > 0) ||
      (intervalDistance != null && intervalDistance! > 0);

  bool matches(FuelType fuelType) => fuelTypes.contains(fuelType);
}

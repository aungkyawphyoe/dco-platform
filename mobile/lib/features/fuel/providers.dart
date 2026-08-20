import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

FuelLogKind fuelLogKindFor(Vehicle vehicle) {
  return FuelLogKind.forVehicleFuelType(vehicle.fuelType.storage);
}

final seedFuelTypesProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(activeVehicleProvider).valueOrNull?.userId;
  if (userId == null) return;
  await ref.watch(fuelRepositoryProvider).ensureDefaultFuelTypes(userId);
});

final vehicleFuelLogKindProvider = Provider<FuelLogKind?>((ref) {
  final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
  if (vehicle == null) return null;
  return fuelLogKindFor(vehicle);
});

final fuelCatalogProvider = StreamProvider<List<FuelCatalogType>>((ref) {
  final userId = ref.watch(activeVehicleProvider).valueOrNull?.userId;
  if (userId == null) return Stream.value(const []);
  return ref.watch(fuelRepositoryProvider).watchFuelTypes(userId);
});

final matchingFuelTypesProvider = Provider<List<FuelCatalogType>>((ref) {
  final kind = ref.watch(vehicleFuelLogKindProvider)?.catalogKind;
  final types = ref.watch(fuelCatalogProvider).valueOrNull ?? const <FuelCatalogType>[];
  if (kind == null) return const [];
  return types.where((type) => type.kind == kind).toList();
});

final vehicleFuelLogsProvider = StreamProvider<List<FuelLog>>((ref) {
  final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
  if (vehicle == null) return Stream.value(const []);
  return ref.watch(fuelRepositoryProvider).watchLogs(
    vehicleId: vehicle.id,
    kind: fuelLogKindFor(vehicle),
  );
});

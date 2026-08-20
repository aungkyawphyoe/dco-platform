import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/parts/domain/entities/part.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehiclePartsProvider = StreamProvider<List<Part>>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(const []);
  return ref.watch(partsRepositoryProvider).watchForVehicle(vehicleId);
});

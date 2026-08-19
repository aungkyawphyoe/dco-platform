import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final garageVehiclesProvider = StreamProvider<List<Vehicle>>((ref) {
  final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
  if (userId == null) return Stream.value(const []);
  return ref.watch(vehicleRepositoryProvider).watchGarage(userId);
});

final activeVehicleProvider = StreamProvider<Vehicle?>((ref) {
  final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
  if (userId == null) return Stream.value(null);
  return ref.watch(vehicleRepositoryProvider).watchActive(userId);
});

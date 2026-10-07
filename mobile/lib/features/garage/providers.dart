import 'package:dco_mobile/core/network/api_error.dart';
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

/// Live lookup for a single vehicle by id, independent of which vehicle
/// is currently active. Drives the vehicle detail screen and any flow
/// that must reference a non-active vehicle.
final vehicleByIdProvider = StreamProvider.family<Vehicle?, String>((ref, vehicleId) {
  if (vehicleId.isEmpty) return Stream.value(null);
  return ref.watch(vehicleRepositoryProvider).watchById(vehicleId);
});

typedef SetActiveVehicle = Future<void> Function(String vehicleId);

/// Switches the active vehicle locally, then propagates to the server
/// best-effort; offline switches are remembered and retried later.
final setActiveVehicleProvider = Provider<SetActiveVehicle>((ref) {
  return (vehicleId) async {
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user.id;
    final displayName = ref.read(sessionControllerProvider).valueOrNull?.user.displayName ?? '';
    if (userId == null) return;
    final profile = ref.read(profileRepositoryProvider);
    await ref
        .read(vehicleRepositoryProvider)
        .setActive(userId: userId, vehicleId: vehicleId);
    try {
      await profile.update(displayName: displayName, activeVehicleId: vehicleId);
    } on ApiError catch (error) {
      if (error.code == 'network') {
        await profile.markPendingActiveVehicle(
          userId: userId,
          vehicleId: vehicleId,
        );
      } else {
        // Re-throw non-network errors (e.g., invalid_vehicle) so caller can show proper error
        rethrow;
      }
    }
  };
});

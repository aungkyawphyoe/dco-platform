import '../entities/vehicle.dart';

abstract class VehicleRepository {
  Stream<List<Vehicle>> watchGarage(String userId);

  Stream<Vehicle?> watchActive(String userId);

  Future<Vehicle?> getById(String id);

  Future<Vehicle> add({
    required String userId,
    required VehicleDraft draft,
  });

  Future<Vehicle> update({
    required String userId,
    required String vehicleId,
    required VehicleDraft draft,
  });

  Future<void> setActive({
    required String userId,
    required String vehicleId,
  });

  Future<void> archive({
    required String userId,
    required String vehicleId,
  });
}

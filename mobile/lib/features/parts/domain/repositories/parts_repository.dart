import '../entities/part.dart';

abstract class PartsRepository {
  Stream<List<Part>> watchForVehicle(String vehicleId);

  Future<Part?> getById(String id);

  Future<Part> add({
    required String userId,
    required String vehicleId,
    required PartDraft draft,
  });

  Future<Part> update({
    required String userId,
    required String partId,
    required PartDraft draft,
  });
}

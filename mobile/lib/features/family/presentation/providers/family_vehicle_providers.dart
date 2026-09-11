import 'package:dco_mobile/features/family/domain/entities/family.dart';
import 'package:dco_mobile/features/family/domain/repositories/family_repository.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final familyVehiclesProvider = FutureProvider<List<FamilyVehicle>>((ref) async {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getFamilyVehicles();
});

final familyActionsProvider = Provider<FamilyActions>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return FamilyActions(repo);
});

class FamilyActions {
  FamilyActions(this._repo);
  final FamilyRepository _repo;

  Future<void> addVehicleToFamily(String vehicleId) async {
    await _repo.addVehicleToFamily(vehicleId);
  }

  Future<void> removeVehicleFromFamily(String vehicleId) async {
    await _repo.removeVehicleFromFamily(vehicleId);
  }
}

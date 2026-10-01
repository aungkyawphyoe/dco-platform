import 'package:dco_mobile/features/family/domain/entities/family.dart';

abstract class FamilyRepository {
  Future<Family?> getMyFamily();
  Future<Family> createFamily(String name);
  Future<Family> joinFamily(String code);
  Future<Family> updateFamily({String? name, bool regenerateShareCode = false});
  Future<void> archiveFamily();
  Future<List<FamilyMember>> getMembers();
  Future<FamilyMember> updateMemberRole(String userId, String role);
  Future<void> removeMember(String userId);
  Future<VehicleGrant> grantVehicleAccess(String vehicleId, String userId, String permission);
  Future<void> revokeVehicleGrant(String grantId);
  Future<List<FamilyVehicle>> getFamilyVehicles();
  Future<void> addVehicleToFamily(String vehicleId);
  Future<void> removeVehicleFromFamily(String vehicleId);
  Future<FamilyVehicleDetail?> getVehicleDetail(String vehicleId);
  Future<UserDetail?> getUserDetail(String userId);
  Future<FamilyVehicleDetail?> getLocalVehicleDetail(String vehicleId);
  Future<UserDetail?> getLocalUserDetail(String userId);
  Future<void> clearFamilyCache();
}

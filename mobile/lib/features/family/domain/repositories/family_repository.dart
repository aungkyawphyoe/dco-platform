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
  Future<DrivingLicense?> getMyLicense();
  Future<DrivingLicense> upsertLicense({
    String? licenseNumber,
    String? issuingCountry,
    required String expiryDate,
    String? categories,
    String? frontMediaId,
    String? backMediaId,
  });
  Future<String> uploadLicenseMedia(String side, List<int> bytes);
  Future<DrivingLicense?> getMemberLicense(String userId);
  Future<FamilyVehicleDetail?> getVehicleDetail(String vehicleId);
  Future<UserDetail?> getUserDetail(String userId);
}

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart';

extension FamilyRecordMapper on FamilyRecord {
  Family toFamily() {
    return Family(
      id: id,
      name: name,
      shareCode: shareCode,
      qrCodeData: qrCodeData,
      status: status,
      createdBy: createdBy,
      createdAt: createdAt,
      archivedAt: archivedAt,
    );
  }
}

extension FamilyMembershipRecordMapper on FamilyMembershipRecord {
  FamilyMember toFamilyMember() {
    return FamilyMember(
      id: id,
      userId: userId,
      email: '',
      displayName: null,
      role: role,
      joinedAt: joinedAt,
      invitedBy: invitedBy,
      vehicleCount: 0,
      licenseStatus: null,
    );
  }
}

extension VehicleGrantRecordMapper on VehicleGrantRecord {
  VehicleGrant toVehicleGrant() {
    return VehicleGrant(
      id: id,
      vehicleId: vehicleId,
      userId: userId,
      grantedBy: grantedBy,
      permission: permission,
      createdAt: createdAt,
    );
  }
}

extension DrivingLicenseRecordMapper on DrivingLicenseRecord {
  DrivingLicense toDrivingLicense() {
    return DrivingLicense(
      id: id,
      userId: userId,
      licenseNumber: licenseNumber,
      issuingCountry: issuingCountry,
      expiryDate: expiryDate,
      categories: categories,
      frontMediaId: frontMediaId,
      backMediaId: backMediaId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

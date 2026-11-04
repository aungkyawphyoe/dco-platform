import 'package:dco_mobile/core/entities/driving_license.dart';

abstract class LicenseRepository {
  Future<DrivingLicense?> getMyLicense();

  Future<void> deleteMyLicense();

  Future<DrivingLicense> upsertLicense({
    String? licenseNumber,
    required String expiryDate,
  });


  Future<DrivingLicense?> getMemberLicense(String userId);
}

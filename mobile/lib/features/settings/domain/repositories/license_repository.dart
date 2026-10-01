import 'package:dco_mobile/core/entities/driving_license.dart';

abstract class LicenseRepository {
  Future<DrivingLicense?> getMyLicense();

  Future<DrivingLicense> upsertLicense({
    String? licenseNumber,
    String? issuingCountry,
    required String expiryDate,
    String? categories,
    String? frontMediaId,
    String? backMediaId,
  });

  Future<String> uploadLicensePhoto(String side, List<int> bytes);

  Future<DrivingLicense?> getMemberLicense(String userId);
}

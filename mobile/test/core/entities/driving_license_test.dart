import 'package:dco_mobile/core/entities/driving_license.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'license without expiry survives cache round trip without a validity claim',
    () {
      final license = DrivingLicense.fromJson({
        'id': 'license',
        'user_id': 'owner',
        'front_media_id': 'front',
        'expiry_date': null,
        'created_at': '2026-10-21T00:00:00Z',
        'updated_at': '2026-10-21T00:00:00Z',
      });
      expect(license.expiryDate, isNull);
      expect(license.status, LicenseStatus.none);
      final cached = DrivingLicense.fromJson(license.toJson());
      expect(cached.expiryDate, isNull);
      expect(cached.frontMediaId, 'front');
    },
  );
}

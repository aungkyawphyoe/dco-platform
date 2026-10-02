import 'package:dco_mobile/features/family/domain/entities/family.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserDetail.fromJson', () {
    Map<String, dynamic> baseJson() => {
          'id': 'user-1',
          'email': 'driver@example.com',
          'role': 'owner',
          'plan': 'free',
          'status': 'active',
          'email_verified': true,
          'created_at': '2025-01-15T10:00:00.000Z',
          'owned_vehicles': <dynamic>[],
        };

    test('parses contact phone, address, and profile photo media id', () {
      final detail = UserDetail.fromJson({
        ...baseJson(),
        'display_name': 'Aye Chan',
        'contact_phone': '+95912345678',
        'address': '123 Yangon Road',
        'profile_photo_media_id': 'media-abc',
      });

      expect(detail.displayName, 'Aye Chan');
      expect(detail.contactPhone, '+95912345678');
      expect(detail.address, '123 Yangon Road');
      expect(detail.profilePhotoMediaId, 'media-abc');
    });

    test('defaults contact fields to null when absent', () {
      final detail = UserDetail.fromJson(baseJson());

      expect(detail.contactPhone, isNull);
      expect(detail.address, isNull);
      expect(detail.profilePhotoMediaId, isNull);
    });

    test('keeps family and license fields intact alongside contact fields', () {
      final detail = UserDetail.fromJson({
        ...baseJson(),
        'contact_phone': '+95999999999',
        'address': 'Mandalay',
        'family_id': 'fam-1',
        'family_role': 'driver',
        'driving_license': {
          'id': 'lic-1',
          'user_id': 'user-1',
          'license_number': 'N-123456',
          'issuing_country': 'MM',
          'expiry_date': '2030-01-01',
          'categories': 'B',
          'front_media_id': 'media-front',
          'back_media_id': 'media-back',
          'created_at': '2025-01-15T10:00:00.000Z',
          'updated_at': '2025-01-15T10:00:00.000Z',
        },
        'owned_vehicles': <dynamic>[],
      });

      expect(detail.contactPhone, '+95999999999');
      expect(detail.address, 'Mandalay');
      expect(detail.familyId, 'fam-1');
      expect(detail.familyRole, 'driver');
      expect(detail.drivingLicense?.frontMediaId, 'media-front');
      expect(detail.drivingLicense?.backMediaId, 'media-back');
    });
  });
}

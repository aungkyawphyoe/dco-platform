import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entitlements.fromJson', () {
    test('parses active Enterprise member with fleet feature', () {
      final entitlements = Entitlements.fromJson({
        'plan': 'free',
        'family': {
          'available': false,
          'role': null,
          'can_create': false,
          'can_manage': false,
        },
        'organization': {
          'id': 'org-1',
          'type': 'business',
          'plan': 'enterprise',
          'status': 'active',
          'role': 'org_admin',
        },
        'features': {'family': false, 'fleet': true},
      });

      expect(entitlements.plan, 'free');
      expect(entitlements.family.available, isFalse);
      expect(entitlements.organization?.id, 'org-1');
      expect(entitlements.organization?.isActiveEnterprise, isTrue);
      expect(entitlements.organization?.canManageOrg, isTrue);
      expect(entitlements.features.fleet, isTrue);
      expect(entitlements.canUseFleet, isTrue);
    });

    test('non-member hides fleet entry', () {
      final entitlements = Entitlements.fromJson({
        'plan': 'free',
        'family': {'available': false, 'can_create': false, 'can_manage': false},
        'organization': null,
        'features': {'family': false, 'fleet': false},
      });

      expect(entitlements.organization, isNull);
      expect(entitlements.canUseFleet, isFalse);
    });

    test('pending organization does not grant fleet access', () {
      final entitlements = Entitlements.fromJson({
        'plan': 'premium',
        'family': {'available': true, 'role': 'primary_owner', 'can_create': false, 'can_manage': true},
        'organization': {
          'id': 'org-2',
          'type': 'business',
          'plan': 'enterprise',
          'status': 'pending',
          'role': 'org_driver',
        },
        'features': {'family': true, 'fleet': false},
      });

      expect(entitlements.features.fleet, isFalse);
      expect(entitlements.canUseFleet, isFalse);
      expect(entitlements.organization?.isDriver, isTrue);
      expect(entitlements.family.canManage, isTrue);
    });

    test('tolerates missing optional maps', () {
      final entitlements = Entitlements.fromJson(const {'plan': 'free'});

      expect(entitlements.features.fleet, isFalse);
      expect(entitlements.family.available, isFalse);
      expect(entitlements.organization, isNull);
    });
  });

  group('MyOrganization.fromJson', () {
    test('parses member organization with access', () {
      final mine = MyOrganization.fromJson({
        'organization': {
          'id': 'org-1',
          'name': 'Acme Fleet',
          'type': 'business',
          'plan': 'enterprise',
          'status': 'active',
          'role': 'org_manager',
          'contact_email': 'ops@acme.test',
          'contact_phone': null,
        },
        'fleet_access': true,
      });

      expect(mine.fleetAccess, isTrue);
      expect(mine.organization?.name, 'Acme Fleet');
      expect(mine.organization?.canOperate, isTrue);
      expect(mine.organization?.canAddVehicles, isTrue);
    });

    test('non-member returns null organization', () {
      final mine = MyOrganization.fromJson({
        'organization': null,
        'fleet_access': false,
      });

      expect(mine.organization, isNull);
      expect(mine.fleetAccess, isFalse);
    });
  });
}

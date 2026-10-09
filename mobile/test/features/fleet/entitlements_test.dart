import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entitlements.fromJson', () {
    test('parses active Enterprise member with fleet feature', () {
      final entitlements = Entitlements.fromJson({
        'plan': 'free',
        'vehicle_sharing': {
          'available': true,
          'can_share': true,
          'limits': {'per_vehicle': 1, 'total': 1},
          'active_shares': 0,
        },
        'organization': {
          'id': 'org-1',
          'type': 'business',
          'plan': 'enterprise',
          'status': 'active',
          'role': 'org_admin',
        },
        'features': {'vehicle_sharing': true, 'fleet': true},
      });

      expect(entitlements.plan, 'free');
      expect(entitlements.vehicleSharing.available, isTrue);
      expect(entitlements.vehicleSharing.perVehicle, 1);
      expect(entitlements.vehicleSharing.total, 1);
      expect(entitlements.organization?.id, 'org-1');
      expect(entitlements.organization?.isActiveEnterprise, isTrue);
      expect(entitlements.organization?.canManageOrg, isTrue);
      expect(entitlements.features.fleet, isTrue);
      expect(entitlements.canUseFleet, isTrue);
    });

    test('non-member hides fleet entry', () {
      final entitlements = Entitlements.fromJson({
        'plan': 'free',
        'vehicle_sharing': {'available': true, 'can_share': true},
        'organization': null,
        'features': {'vehicle_sharing': true, 'fleet': false},
      });

      expect(entitlements.organization, isNull);
      expect(entitlements.canUseFleet, isFalse);
    });

    test('pending organization does not grant fleet access', () {
      final entitlements = Entitlements.fromJson({
        'plan': 'standard',
        'vehicle_sharing': {
          'available': true,
          'can_share': true,
          'limits': {'per_vehicle': null, 'total': null},
          'active_shares': 2,
        },
        'organization': {
          'id': 'org-2',
          'type': 'business',
          'plan': 'enterprise',
          'status': 'pending',
          'role': 'org_driver',
        },
        'features': {'vehicle_sharing': true, 'fleet': false},
      });

      expect(entitlements.features.fleet, isFalse);
      expect(entitlements.canUseFleet, isFalse);
      expect(entitlements.organization?.isDriver, isTrue);
      expect(entitlements.vehicleSharing.activeShares, 2);
      expect(entitlements.vehicleSharing.perVehicle, isNull);
      expect(entitlements.vehicleSharing.total, isNull);
    });

    test('tolerates missing optional maps', () {
      final entitlements = Entitlements.fromJson(const {'plan': 'free'});

      expect(entitlements.features.fleet, isFalse);
      expect(entitlements.vehicleSharing.available, isFalse);
      expect(entitlements.vehicleSharing.perVehicle, 1);
      expect(entitlements.vehicleSharing.total, 1);
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

import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverPlanItem.fromJson', () {
    test('parses a full plan item', () {
      final item = DriverPlanItem.fromJson(const {
        'id': 'plan-1',
        'vehicle_id': 'veh-1',
        'name': 'Oil Change',
        'interval_days': 180,
        'interval_distance': 10000,
        'next_due_mileage': 45000,
        'next_due_on': '2026-03-12',
        'enabled': true,
        'notes': 'Synthetic 5W-30',
        'catalog_key': 'oil_change',
        'created_by': 'user-9',
      });

      expect(item.id, 'plan-1');
      expect(item.vehicleId, 'veh-1');
      expect(item.name, 'Oil Change');
      expect(item.intervalDays, 180);
      expect(item.intervalDistance, 10000);
      expect(item.nextDueMileage, 45000);
      expect(item.nextDueOn, '2026-03-12');
      expect(item.enabled, isTrue);
      expect(item.catalogKey, 'oil_change');
      expect(item.createdBy, 'user-9');
    });

    test('applies defaults for sparse payloads', () {
      final item = DriverPlanItem.fromJson(const {
        'id': 'plan-2',
        'name': 'Brake pads',
      });

      expect(item.vehicleId, '');
      expect(item.intervalDays, isNull);
      expect(item.intervalDistance, isNull);
      expect(item.nextDueMileage, isNull);
      expect(item.nextDueOn, isNull);
      expect(item.enabled, isTrue);
      expect(item.notes, isNull);
    });

    test('is overdue when the due date has passed', () {
      final item = DriverPlanItem.fromJson(const {
        'id': 'plan-3',
        'vehicle_id': 'veh-1',
        'name': 'Oil Change',
        'next_due_on': '2026-01-01',
        'enabled': true,
      });

      expect(
        item.isOverdue(now: DateTime(2026, 6, 1), currentMileage: 0),
        isTrue,
      );
      expect(
        item.isOverdue(now: DateTime(2025, 6, 1), currentMileage: 0),
        isFalse,
      );
    });

    test('is overdue when mileage reaches the next-due mileage', () {
      final item = DriverPlanItem.fromJson(const {
        'id': 'plan-4',
        'vehicle_id': 'veh-1',
        'name': 'Tyres',
        'next_due_mileage': 45000,
        'enabled': true,
      });

      expect(
        item.isOverdue(now: DateTime(2026, 6, 1), currentMileage: 45000),
        isTrue,
      );
      expect(
        item.isOverdue(now: DateTime(2026, 6, 1), currentMileage: 44999),
        isFalse,
      );
    });
  });

  group('DriverSuggestedPlanItem.fromJson', () {
    test('parses a template-set row', () {
      final item = DriverSuggestedPlanItem.fromJson(const {
        'catalog_key': 'brake_fluid',
        'name': 'Brake Fluid',
        'interval_days': 365,
        'interval_distance': null,
        'vehicle_class': 'car',
      });

      expect(item.catalogKey, 'brake_fluid');
      expect(item.name, 'Brake Fluid');
      expect(item.intervalDays, 365);
      expect(item.intervalDistance, isNull);
      expect(item.vehicleClass, 'car');
      expect(item.hasInterval, isTrue);
    });

    test('hasInterval is false without a usable interval', () {
      final item = DriverSuggestedPlanItem.fromJson(const {
        'catalog_key': 'inspection',
        'name': 'General inspection',
      });

      expect(item.hasInterval, isFalse);
    });
  });
}

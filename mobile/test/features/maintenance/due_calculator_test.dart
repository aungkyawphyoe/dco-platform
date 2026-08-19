import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/plan_item_validators.dart';
import 'package:dco_mobile/features/maintenance/domain/suggested_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

PlanItem _item({
  int? intervalDays,
  double? intervalDistance,
  DateTime? nextDueOn,
  double? nextDueMileage,
  bool enabled = true,
}) {
  final now = DateTime(2026, 8, 19);
  return PlanItem(
    id: 'p1',
    vehicleId: 'v1',
    name: 'Oil Change',
    intervalDays: intervalDays,
    intervalDistance: intervalDistance,
    nextDueOn: nextDueOn,
    nextDueMileage: nextDueMileage,
    enabled: enabled,
    updatedAt: now,
    createdAt: now,
  );
}

void main() {
  group('DueCalculator', () {
    final now = DateTime(2026, 8, 19);

    test('recurring next due uses tracking start plus intervals', () {
      final due = DueCalculator.fromDraft(
        draft: PlanItemDraft(
          name: 'Oil',
          recurring: true,
          intervalDays: 365,
          intervalDistance: 15000,
          date: DateTime(2026, 1, 1),
          mileage: 10000,
        ),
        now: now,
        currentMileage: 12000,
      );
      expect(due.on, DateTime(2027, 1, 1));
      expect(due.mileage, 25000);
    });

    test('active next due uses the date and mileage as-is', () {
      final due = DueCalculator.fromDraft(
        draft: PlanItemDraft(
          name: 'Inspection',
          recurring: false,
          date: DateTime(2026, 9, 1),
          mileage: 20000,
        ),
        now: now,
        currentMileage: 10000,
      );
      expect(due.on, DateTime(2026, 9, 1));
      expect(due.mileage, 20000);
    });

    test('overdue by date or mileage is upcoming', () {
      final overdueDate = DueCalculator.urgency(
        item: _item(nextDueOn: DateTime(2026, 8, 1)),
        vehicleMileage: 1000,
        now: now,
      );
      final overdueMiles = DueCalculator.urgency(
        item: _item(nextDueMileage: 9000),
        vehicleMileage: 10000,
        now: now,
      );
      expect(overdueDate, PlanUrgency.overdue);
      expect(overdueMiles, PlanUrgency.overdue);
      expect(DueCalculator.isUpcoming(overdueDate), isTrue);
    });

    test('due within 30 days or 500 miles is upcoming', () {
      final soonDate = DueCalculator.urgency(
        item: _item(nextDueOn: DateTime(2026, 9, 1)),
        vehicleMileage: 1000,
        now: now,
      );
      final soonMiles = DueCalculator.urgency(
        item: _item(nextDueMileage: 10400),
        vehicleMileage: 10000,
        now: now,
      );
      expect(soonDate, PlanUrgency.dueSoon);
      expect(soonMiles, PlanUrgency.dueSoon);
    });

    test('far-future items are scheduled', () {
      final status = DueCalculator.urgency(
        item: _item(nextDueOn: DateTime(2027, 1, 1), nextDueMileage: 20000),
        vehicleMileage: 10000,
        now: now,
      );
      expect(status, PlanUrgency.scheduled);
    });

    test('completing a recurring item advances next due from the service', () {
      final next = DueCalculator.afterService(
        item: _item(intervalDays: 365, intervalDistance: 15000),
        servicedOn: DateTime(2026, 8, 19),
        odometer: 12000,
      );
      expect(next.on, DateTime(2027, 8, 19));
      expect(next.mileage, 27000);
    });

    test('completing a one-time item clears next due', () {
      final next = DueCalculator.afterService(
        item: _item(nextDueOn: DateTime(2026, 8, 19)),
        servicedOn: DateTime(2026, 8, 19),
        odometer: 12000,
      );
      expect(next.on, isNull);
      expect(next.mileage, isNull);
    });
  });

  group('PlanItemValidators', () {
    test('name is required and capped', () {
      expect(PlanItemValidators.name('  '), isNotNull);
      expect(PlanItemValidators.name('Oil'), isNull);
      expect(PlanItemValidators.name('x' * 81), isNotNull);
    });

    test('recurring needs a time or distance interval', () {
      expect(
        PlanItemValidators.schedule(recurring: true),
        isNotNull,
      );
      expect(
        PlanItemValidators.schedule(recurring: true, intervalDays: 365),
        isNull,
      );
    });

    test('active needs a date or mileage', () {
      expect(PlanItemValidators.schedule(recurring: false), isNotNull);
      expect(
        PlanItemValidators.schedule(recurring: false, mileage: 15000),
        isNull,
      );
    });
  });

  group('SuggestedCatalog', () {
    test('hides engine items for electric vehicles', () {
      final petrol = SuggestedCatalog.forFuelType(FuelType.petrol);
      final electric = SuggestedCatalog.forFuelType(FuelType.electric);
      expect(petrol.any((item) => item.catalogKey == 'oil_change'), isTrue);
      expect(electric.any((item) => item.catalogKey == 'oil_change'), isFalse);
      expect(electric.any((item) => item.catalogKey == 'rotate_tires'), isTrue);
    });
  });
}

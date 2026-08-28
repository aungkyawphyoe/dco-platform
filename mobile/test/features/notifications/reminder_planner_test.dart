import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/notifications/domain/entities/notification.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_planner.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:flutter_test/flutter_test.dart';

PlanItem _item({
  String id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  String name = 'Oil Change',
  DateTime? nextDueOn,
  double? nextDueMileage,
  bool enabled = true,
}) {
  final now = DateTime(2026, 8, 28);
  return PlanItem(
    id: id,
    vehicleId: 'v1',
    name: name,
    nextDueOn: nextDueOn,
    nextDueMileage: nextDueMileage,
    enabled: enabled,
    updatedAt: now,
    createdAt: now,
  );
}

Vehicle _vehicle({double mileage = 10000}) {
  final now = DateTime(2026, 8, 28);
  return Vehicle(
    id: 'v1',
    userId: 'u1',
    name: 'Daily',
    make: 'Toyota',
    model: 'Camry',
    year: 2022,
    licensePlate: 'ABC123',
    fuelType: FuelType.petrol,
    mileage: mileage,
    mileageUnit: MileageUnit.mi,
    archived: false,
    updatedAt: now,
    createdAt: now,
  );
}

void main() {
  final now = DateTime(2026, 8, 28, 12);

  group('ReminderPolicy', () {
    test('fires when remaining time is under 7 days', () {
      final start = ReminderPolicy.dateWindowStart(DateTime(2026, 9, 2));
      expect(start, DateTime(2026, 8, 26, 9));
      expect(!start!.isAfter(now), isTrue);
    });

    test('schedules 09:00 on the day remaining time first drops below 7 days', () {
      final start = ReminderPolicy.dateWindowStart(DateTime(2026, 9, 10));
      expect(start, DateTime(2026, 9, 3, 9));
      expect(start!.isAfter(now), isTrue);
    });

    test('mileage due-soon uses 60 mi when the owner prefers miles', () {
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: 10059,
          vehicleMileage: 10000,
          lengthUnit: MileageUnit.mi,
        ),
        isTrue,
      );
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: 10061,
          vehicleMileage: 10000,
          lengthUnit: MileageUnit.mi,
        ),
        isFalse,
      );
    });

    test('mileage due-soon uses 100 km when the owner prefers kilometers', () {
      final due = 10000 + MileageUnit.km.toStorage(100);
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: due,
          vehicleMileage: 10000,
          lengthUnit: MileageUnit.km,
        ),
        isTrue,
      );
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: due + 1,
          vehicleMileage: 10000,
          lengthUnit: MileageUnit.km,
        ),
        isFalse,
      );
    });

    test('OS copy is the fixed title plus the service name', () {
      expect(ReminderPolicy.osTitle, 'Maintenance Reminder');
      expect(ReminderPolicy.osBody('Oil Change'), 'Oil Change');
      expect(ReminderPolicy.osBody('x' * 200).length, ReminderPolicy.bodyMax);
    });
  });

  group('ReminderPlanner', () {
    test('shows now when the date window has opened', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 9, 1))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(actions.single.kind, ReminderActionKind.showNow);
      expect(actions.single.dueReason, NotificationDueReason.date);
      expect(actions.single.serviceName, 'Oil Change');
    });

    test('shows now when remaining mileage is under 60 mi', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle(mileage: 10000)],
        items: [_item(nextDueMileage: 10040)],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(actions.single.kind, ReminderActionKind.showNow);
      expect(actions.single.dueReason, NotificationDueReason.mileage);
    });

    test('fires on whichever of date or mileage hits first', () {
      final mileageFirst = ReminderPlanner.plan(
        garage: [_vehicle(mileage: 10000)],
        items: [
          _item(nextDueOn: DateTime(2026, 10, 1), nextDueMileage: 10020),
        ],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(mileageFirst.single.kind, ReminderActionKind.showNow);
      expect(mileageFirst.single.dueReason, NotificationDueReason.mileage);

      final dateFirst = ReminderPlanner.plan(
        garage: [_vehicle(mileage: 10000)],
        items: [
          _item(nextDueOn: DateTime(2026, 9, 1), nextDueMileage: 20000),
        ],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(dateFirst.single.kind, ReminderActionKind.showNow);
      expect(dateFirst.single.dueReason, NotificationDueReason.date);
    });

    test('schedules a future date window at local 09:00', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 9, 20))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(actions.single.kind, ReminderActionKind.schedule);
      expect(actions.single.fireAt, DateTime(2026, 9, 13, 9));
    });

    test('does not fire twice for the same due cycle', () {
      final item = _item(nextDueOn: DateTime(2026, 9, 1));
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [item],
        deliveredCycleKeys: {
          ReminderPolicy.deliveredKey(item.id, ReminderPolicy.cycleKey(item)),
        },
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(actions.single.kind, ReminderActionKind.cancel);
    });

    test('records feed only when a scheduled alarm has already elapsed', () {
      final item = _item(nextDueOn: DateTime(2026, 9, 1));
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [item],
        deliveredCycleKeys: const {},
        scheduled: [
          ScheduledReminder(
            planItemId: item.id,
            cycleKey: ReminderPolicy.cycleKey(item),
            fireAt: DateTime(2026, 8, 25, 9),
          ),
        ],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(actions.single.kind, ReminderActionKind.recordFeedOnly);
    });

    test('cancels disabled items and items on archived vehicles', () {
      final disabled = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 9, 1), enabled: false)],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(disabled.single.kind, ReminderActionKind.cancel);

      final archived = ReminderPlanner.plan(
        garage: const [],
        items: [_item(nextDueOn: DateTime(2026, 9, 1))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        lengthUnit: MileageUnit.mi,
      );
      expect(archived.single.kind, ReminderActionKind.cancel);
    });
  });
}

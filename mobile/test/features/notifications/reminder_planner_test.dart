import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
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

ReminderAction _phase(Iterable<ReminderAction> actions, ReminderPhase phase) {
  return actions.firstWhere((action) => action.phase == phase);
}

void main() {
  final now = DateTime(2026, 8, 28, 12);

  group('ReminderPolicy', () {
    test('upcoming window opens at soon days before the due date at 09:00', () {
      final start = ReminderPolicy.windowStart(
        DateTime(2026, 10, 15),
        phase: ReminderPhase.upcoming,
        thresholds: DueThresholds.defaults,
      );
      expect(start, DateTime(2026, 9, 15, 9));
    });

    test('due window is the due date itself at 09:00', () {
      final start = ReminderPolicy.windowStart(
        DateTime(2026, 10, 15),
        phase: ReminderPhase.due,
        thresholds: DueThresholds.defaults,
      );
      expect(start, DateTime(2026, 10, 15, 9));
    });

    test('windows are null when the item has no due date', () {
      expect(
        ReminderPolicy.windowStart(
          null,
          phase: ReminderPhase.upcoming,
          thresholds: DueThresholds.defaults,
        ),
        isNull,
      );
      expect(
        ReminderPolicy.windowStart(
          null,
          phase: ReminderPhase.due,
          thresholds: DueThresholds.defaults,
        ),
        isNull,
      );
    });

    test('mileage due-soon compares against the configured threshold', () {
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: 10310,
          vehicleMileage: 10000,
          thresholds: DueThresholds.defaults,
        ),
        isTrue,
      );
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: 10320,
          vehicleMileage: 10000,
          thresholds: DueThresholds.defaults,
        ),
        isFalse,
      );
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: null,
          vehicleMileage: 10000,
          thresholds: DueThresholds.defaults,
        ),
        isFalse,
      );
    });

    test('mileage due-soon honors a custom threshold', () {
      const strict = DueThresholds(soonDays: 7, soonDistanceKm: 100);
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: 10060,
          vehicleMileage: 10000,
          thresholds: strict,
        ),
        isTrue,
      );
      expect(
        ReminderPolicy.mileageDueSoon(
          nextDueMileage: 10070,
          vehicleMileage: 10000,
          thresholds: strict,
        ),
        isFalse,
      );
    });

    test('OS ids are stable, 31-bit, and distinct per phase', () {
      const id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
      final due = ReminderPolicy.osId(id, phase: ReminderPhase.due);
      final upcoming = ReminderPolicy.osId(id, phase: ReminderPhase.upcoming);
      expect(due, ReminderPolicy.osId(id, phase: ReminderPhase.due));
      expect(due, isNot(upcoming));
      expect(due & 0x7fffffff, due);
      expect(upcoming & 0x7fffffff, upcoming);
      expect(due, greaterThanOrEqualTo(0));
      expect(upcoming, greaterThanOrEqualTo(0));
    });

    test('stored cycle keys scope the upcoming phase independently', () {
      final item = _item(nextDueOn: DateTime(2026, 9, 1), nextDueMileage: 10050);
      final base = ReminderPolicy.cycleKey(item);
      expect(ReminderPolicy.storedCycleKey(item, ReminderPhase.due), base);
      expect(
        ReminderPolicy.storedCycleKey(item, ReminderPhase.upcoming),
        '$base#upcoming',
      );
    });

    test('clips copy to the configured maximum', () {
      expect(ReminderPolicy.clip('x' * 200, ReminderPolicy.bodyMax).length,
          ReminderPolicy.bodyMax);
      expect(ReminderPolicy.clip('  Oil Change  ', ReminderPolicy.bodyMax),
          'Oil Change');
    });
  });

  group('ReminderPlanner', () {
    test('schedules both reminders for a future due date', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 10, 15))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(actions, hasLength(2));
      final due = _phase(actions, ReminderPhase.due);
      expect(due.kind, ReminderActionKind.schedule);
      expect(due.fireAt, DateTime(2026, 10, 15, 9));
      final upcoming = _phase(actions, ReminderPhase.upcoming);
      expect(upcoming.kind, ReminderActionKind.schedule);
      expect(upcoming.fireAt, DateTime(2026, 9, 15, 9));
      expect(upcoming.serviceName, 'Oil Change');
      expect(upcoming.dueOn, DateTime(2026, 10, 15));
    });

    test('shows the upcoming banner inside the 30-day window', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 9, 20))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      final upcoming = _phase(actions, ReminderPhase.upcoming);
      expect(upcoming.kind, ReminderActionKind.showNow);
      expect(upcoming.dueReason, NotificationDueReason.date);
      final due = _phase(actions, ReminderPhase.due);
      expect(due.kind, ReminderActionKind.schedule);
      expect(due.fireAt, DateTime(2026, 9, 20, 9));
    });

    test('a narrow soon-days window schedules the upcoming reminder', () {
      const strict = DueThresholds(soonDays: 7, soonDistanceKm: 500);
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 9, 20))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: strict,
      );
      // 23 days out: outside a 7-day window, so nothing shows yet.
      final upcoming = _phase(actions, ReminderPhase.upcoming);
      expect(upcoming.kind, ReminderActionKind.schedule);
      expect(upcoming.fireAt, DateTime(2026, 9, 13, 9));
      expect(_phase(actions, ReminderPhase.due).kind, ReminderActionKind.schedule);
    });

    test('shows the due banner on the due date and suppresses upcoming', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 8, 27))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      final due = _phase(actions, ReminderPhase.due);
      expect(due.kind, ReminderActionKind.showNow);
      expect(due.dueReason, NotificationDueReason.date);
      expect(_phase(actions, ReminderPhase.upcoming).kind,
          ReminderActionKind.cancel);
    });

    test('shows the due banner when remaining mileage is under the soon distance', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle(mileage: 10000)],
        items: [_item(nextDueMileage: 10040)],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      final due = _phase(actions, ReminderPhase.due);
      expect(due.kind, ReminderActionKind.showNow);
      expect(due.dueReason, NotificationDueReason.mileage);
      expect(_phase(actions, ReminderPhase.upcoming).kind,
          ReminderActionKind.cancel);
    });

    test('reports both reasons when date and mileage hit together', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle(mileage: 10000)],
        items: [
          _item(nextDueOn: DateTime(2026, 8, 27), nextDueMileage: 10040),
        ],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(
        _phase(actions, ReminderPhase.due).dueReason,
        NotificationDueReason.both,
      );
    });

    test('keeps the upcoming schedule when mileage hits first', () {
      final actions = ReminderPlanner.plan(
        garage: [_vehicle(mileage: 10000)],
        items: [
          _item(nextDueOn: DateTime(2026, 10, 15), nextDueMileage: 10040),
        ],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(_phase(actions, ReminderPhase.due).kind, ReminderActionKind.showNow);
      final upcoming = _phase(actions, ReminderPhase.upcoming);
      expect(upcoming.kind, ReminderActionKind.schedule);
      expect(upcoming.fireAt, DateTime(2026, 9, 15, 9));
    });

    test('does not fire either phase twice for the same cycle', () {
      final item = _item(nextDueOn: DateTime(2026, 9, 20));
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [item],
        deliveredCycleKeys: {
          ReminderPolicy.deliveredKey(
              item.id, ReminderPolicy.storedCycleKey(item, ReminderPhase.due)),
          ReminderPolicy.deliveredKey(item.id,
              ReminderPolicy.storedCycleKey(item, ReminderPhase.upcoming)),
        },
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(
        actions.map((action) => action.kind),
        everyElement(ReminderActionKind.cancel),
      );
    });

    test('records feed only when the due alarm already elapsed', () {
      final item = _item(nextDueOn: DateTime(2026, 8, 25));
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [item],
        deliveredCycleKeys: const {},
        scheduled: [
          ScheduledReminder(
            planItemId: item.id,
            phase: ReminderPhase.due,
            cycleKey: ReminderPolicy.storedCycleKey(item, ReminderPhase.due),
            fireAt: DateTime(2026, 8, 25, 9),
          ),
        ],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(_phase(actions, ReminderPhase.due).kind,
          ReminderActionKind.recordFeedOnly);
      expect(_phase(actions, ReminderPhase.upcoming).kind,
          ReminderActionKind.cancel);
    });

    test('records feed only when the upcoming alarm already elapsed', () {
      final item = _item(nextDueOn: DateTime(2026, 9, 20));
      final actions = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [item],
        deliveredCycleKeys: const {},
        scheduled: [
          ScheduledReminder(
            planItemId: item.id,
            phase: ReminderPhase.upcoming,
            cycleKey: ReminderPolicy.storedCycleKey(item, ReminderPhase.upcoming),
            fireAt: DateTime(2026, 8, 21, 9),
          ),
        ],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(_phase(actions, ReminderPhase.upcoming).kind,
          ReminderActionKind.recordFeedOnly);
      expect(_phase(actions, ReminderPhase.due).kind,
          ReminderActionKind.schedule);
    });

    test('cancels disabled items and items on archived vehicles', () {
      final disabled = ReminderPlanner.plan(
        garage: [_vehicle()],
        items: [_item(nextDueOn: DateTime(2026, 9, 1), enabled: false)],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(disabled, hasLength(2));
      expect(
        disabled.map((action) => action.kind),
        everyElement(ReminderActionKind.cancel),
      );

      final archived = ReminderPlanner.plan(
        garage: const [],
        items: [_item(nextDueOn: DateTime(2026, 9, 1))],
        deliveredCycleKeys: const {},
        scheduled: const [],
        now: now,
        thresholds: DueThresholds.defaults,
      );
      expect(archived, hasLength(2));
      expect(
        archived.map((action) => action.kind),
        everyElement(ReminderActionKind.cancel),
      );
    });
  });
}

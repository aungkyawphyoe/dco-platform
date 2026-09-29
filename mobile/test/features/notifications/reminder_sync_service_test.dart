import 'dart:ui';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/notifications/local_notification_client.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/notifications/data/reminder_schedule_store.dart';
import 'package:dco_mobile/features/notifications/data/reminder_sync_service.dart';
import 'package:dco_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl vehicles;
  late ExpenseRepositoryImpl expenses;
  late MaintenanceRepositoryImpl maintenance;
  late NotificationRepositoryImpl notifications;
  late ReminderScheduleStore schedules;
  late NoopLocalNotificationClient client;
  late ReminderSyncService service;
  const locale = Locale('en');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db);
    vehicles = VehicleRepositoryImpl(db: db, outbox: outbox);
    expenses = ExpenseRepositoryImpl(db: db, outbox: outbox);
    maintenance = MaintenanceRepositoryImpl(db: db, outbox: outbox, expenseRepository: expenses);
    notifications = NotificationRepositoryImpl(db: db, outbox: outbox);
    schedules = ReminderScheduleStore(db);
    client = NoopLocalNotificationClient();
    service = ReminderSyncService(
      notifications: client,
      notificationsRepo: notifications,
      schedules: schedules,
      analytics: const Analytics(),
    );
  });

  tearDown(() => db.close());

  Future<Vehicle> addVehicle() {
    return vehicles.add(
      userId: 'u1',
      draft: VehicleDraft(
        name: 'Daily',
        make: 'Toyota',
        model: 'Camry',
        year: 2022,
        licensePlate: 'ABC123',
        fuelType: FuelType.petrol,
        mileage: 10000,
        mileageUnit: MileageUnit.mi,
      ),
    );
  }

  Future<PlanItem> addPlanItem(Vehicle vehicle, DateTime dueOn) {
    return maintenance.addPlanItem(
      userId: 'u1',
      vehicle: vehicle,
      draft: PlanItemDraft(
        name: 'Oil Change',
        recurring: false,
        date: dueOn,
      ),
    );
  }

  test('schedules the due reminder and shows the upcoming banner', () async {
    final vehicle = await addVehicle();
    final item = await addPlanItem(vehicle, DateTime.now().add(const Duration(days: 3)));

    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: locale,
    );

    expect(
      client.scheduled,
      [ReminderPolicy.osId(item.id, phase: ReminderPhase.due)],
    );
    expect(
      client.shown,
      [ReminderPolicy.osId(item.id, phase: ReminderPhase.upcoming)],
    );
    expect(client.askedPermission, isTrue);

    final feed = await notifications.watch('u1').first;
    expect(feed, hasLength(1));
    final row = feed.single;
    expect(row.title, 'Upcoming maintenance');
    expect(row.body, contains('Oil Change'));
    expect(row.body, contains(DateFormat.yMMMd('en').format(item.nextDueOn!)));
  });

  test('does not show the OS banner twice for the same cycle', () async {
    final vehicle = await addVehicle();
    final item = await addPlanItem(vehicle, DateTime.now().add(const Duration(days: 2)));

    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: locale,
    );
    client.shown.clear();
    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: locale,
    );

    expect(client.shown, isEmpty);
    expect(await notifications.watch('u1').first, hasLength(1));
  });

  test('shows the due banner once when the item is overdue', () async {
    final vehicle = await addVehicle();
    final item = await addPlanItem(vehicle, DateTime.now().subtract(const Duration(days: 1)));

    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: locale,
    );

    expect(
      client.shown,
      [ReminderPolicy.osId(item.id, phase: ReminderPhase.due)],
    );
    final feed = await notifications.watch('u1').first;
    expect(feed, hasLength(1));
    expect(feed.single.title, 'Maintenance due');
    expect(feed.single.body, contains('Oil Change'));

    client.shown.clear();
    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: locale,
    );

    expect(client.shown, isEmpty);
    expect(await notifications.watch('u1').first, hasLength(1));
  });

  test('schedules both phases without showing a banner when far out', () async {
    final vehicle = await addVehicle();
    final item = await addPlanItem(vehicle, DateTime.now().add(const Duration(days: 45)));

    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: locale,
    );

    expect(client.shown, isEmpty);
    expect(
      client.scheduled,
      containsAll({
        ReminderPolicy.osId(item.id, phase: ReminderPhase.due),
        ReminderPolicy.osId(item.id, phase: ReminderPhase.upcoming),
      }),
    );
    expect(await notifications.watch('u1').first, isEmpty);
  });

  test('a wider soon-days window fires early and drops the stale alarm', () async {
    final vehicle = await addVehicle();
    final item = await addPlanItem(vehicle, DateTime.now().add(const Duration(days: 45)));

    // Default 30-day window: both phases are still scheduled.
    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: locale,
    );
    final upcomingId = ReminderPolicy.osId(item.id, phase: ReminderPhase.upcoming);
    final dueId = ReminderPolicy.osId(item.id, phase: ReminderPhase.due);
    expect(client.shown, isEmpty);
    expect(client.scheduled, containsAll({dueId, upcomingId}));
    expect(await notifications.watch('u1').first, isEmpty);

    // Raising soonDays to 60 puts the item inside the window today.
    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: const DueThresholds(soonDays: 60, soonDistanceKm: 500),
      locale: locale,
    );
    expect(client.shown, [upcomingId]);
    // The stale upcoming alarm is gone; only the due alarm stays pending.
    expect(client.scheduled.toSet(), {dueId});
    expect(await notifications.watch('u1').first, hasLength(1));
  });

  test('renders Burmese copy when the locale is my', () async {
    final vehicle = await addVehicle();
    final item = await addPlanItem(vehicle, DateTime.now().add(const Duration(days: 3)));

    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
      thresholds: DueThresholds.defaults,
      locale: const Locale('my'),
    );

    final feed = await notifications.watch('u1').first;
    expect(feed, hasLength(1));
    expect(
      feed.single.title,
      lookupAppLocalizations(const Locale('my')).notificationsReminderUpcomingTitle,
    );
    expect(feed.single.body, contains('Oil Change'));
  });
}

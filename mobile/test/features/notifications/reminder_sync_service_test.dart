import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/notifications/local_notification_client.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/notifications/data/reminder_schedule_store.dart';
import 'package:dco_mobile/features/notifications/data/reminder_sync_service.dart';
import 'package:dco_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl vehicles;
  late ExpenseRepositoryImpl expenses;
  late MaintenanceRepositoryImpl maintenance;
  late NotificationRepositoryImpl notifications;
  late ReminderScheduleStore schedules;
  late NoopLocalNotificationClient client;
  late ReminderSyncService service;

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

  test('shows an OS notification and feed row when a service is due soon', () async {
    final vehicle = await vehicles.add(
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
    final item = await maintenance.addPlanItem(
      userId: 'u1',
      vehicle: vehicle,
      draft: PlanItemDraft(
        name: 'Oil Change',
        recurring: false,
        date: DateTime.now().add(const Duration(days: 3)),
      ),
    );

    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
    );

    expect(client.shown, [ReminderPolicy.osId(item.id)]);
    expect(client.askedPermission, isTrue);
    final feed = await notifications.watch('u1').first;
    expect(feed, hasLength(1));
    expect(feed.single.title, 'Maintenance Reminder');
    expect(feed.single.body, 'Oil Change');
  });

  test('does not show the OS banner twice for the same cycle', () async {
    final vehicle = await vehicles.add(
      userId: 'u1',
      draft: VehicleDraft(
        name: 'Daily',
        make: 'Toyota',
        model: 'Camry',
        year: 2022,
        licensePlate: 'ABC123',
        fuelType: FuelType.petrol,
        mileage: 10000,
      ),
    );
    final item = await maintenance.addPlanItem(
      userId: 'u1',
      vehicle: vehicle,
      draft: PlanItemDraft(
        name: 'Oil Change',
        recurring: false,
        date: DateTime.now().add(const Duration(days: 2)),
      ),
    );

    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
    );
    client.shown.clear();
    await service.sync(
      userId: 'u1',
      garage: [vehicle],
      items: [item],
      lengthUnit: MileageUnit.mi,
    );

    expect(client.shown, isEmpty);
    expect(await notifications.watch('u1').first, hasLength(1));
  });
}

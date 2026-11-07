import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/domain/maintenance_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleDraft _vehicleDraft({double mileage = 10000}) {
  return VehicleDraft(
    name: 'Daily',
    make: 'Toyota',
    model: 'Camry',
    year: 2022,
    licensePlate: 'ABC123',
    fuelType: FuelType.petrol,
    mileage: mileage,
  );
}

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl vehicles;
  late ExpenseRepositoryImpl expenses;
  late MaintenanceRepositoryImpl maintenance;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db);
    vehicles = VehicleRepositoryImpl(db: db, outbox: outbox);
    expenses = ExpenseRepositoryImpl(db: db, outbox: outbox);
    maintenance = MaintenanceRepositoryImpl(
      db: db,
      outbox: outbox,
      expenseRepository: expenses,
    );
  });

  tearDown(() => db.close());

  Future<Vehicle> addVehicle() {
    return vehicles.add(userId: 'user-1', draft: _vehicleDraft());
  }

  test(
    'history orders by service date then newest creation on the same day',
    () async {
      final vehicle = await addVehicle();
      final day = DateTime(2026, 11, 7);
      for (final entry in [
        (id: 'first', date: day, created: day.add(const Duration(hours: 8))),
        (id: 'second', date: day, created: day.add(const Duration(hours: 9))),
        (
          id: 'car-wash',
          date: day,
          created: day.add(const Duration(hours: 10)),
        ),
        (
          id: 'backdated',
          date: day.subtract(const Duration(days: 1)),
          created: day.add(const Duration(hours: 11)),
        ),
      ]) {
        await db
            .into(db.serviceRecordRows)
            .insert(
              ServiceRecordRowsCompanion.insert(
                id: entry.id,
                vehicleId: vehicle.id,
                title: entry.id,
                servicedOn: entry.date,
                totalCost: 7000,
                createdAt: entry.created,
                updatedAt: entry.created,
              ),
            );
      }
      final history = await maintenance.watchHistory(vehicle.id).first;
      expect(history.map((record) => record.id), [
        'car-wash',
        'second',
        'first',
        'backdated',
      ]);
    },
  );

  test('new vehicles start without automatic reminders', () async {
    final vehicle = await addVehicle();
    expect(await maintenance.watchPlan(vehicle.id).first, isEmpty);
  });

  test(
    'registering a service writes history, advances recurring due, and bumps mileage',
    () async {
      final vehicle = await addVehicle();
      final item = await maintenance.addPlanItem(
        userId: 'user-1',
        vehicle: vehicle,
        draft: PlanItemDraft(
          name: 'Oil Change',
          recurring: true,
          intervalDays: 365,
          intervalDistance: 15000,
          date: DateTime(2027),
          mileage: 15000,
          catalogKey: 'oil_change',
        ),
      );

      final record = await maintenance.registerService(
        userId: 'user-1',
        vehicle: vehicle,
        draft: ServiceRecordDraft(
          title: 'Oil Change',
          servicedOn: DateTime(2026, 8, 19),
          odometer: 12000,
          totalCost: 85,
          items: [
            ServiceLineDraft(
              name: 'Oil Change',
              planItemId: item.id,
              lineCost: 85,
            ),
          ],
        ),
      );

      expect(record.totalCost, 85);
      final history = await maintenance.watchHistory(vehicle.id).first;
      expect(history, hasLength(1));
      expect(history.single.items, hasLength(1));

      final updatedPlan = await maintenance.getPlanItem(item.id);
      expect(updatedPlan?.nextDueOn, DateTime(2027, 8, 19));
      expect(updatedPlan?.nextDueMileage, 27000);
      expect(updatedPlan?.enabled, isTrue);

      final updatedVehicle = await vehicles.getById(vehicle.id);
      expect(updatedVehicle?.mileage, 12000);

      final queued = await db.select(db.outboxEntries).get();
      expect(queued.any((row) => row.entityType == 'service_record'), isTrue);
      expect(queued.any((row) => row.entityType == 'plan_item'), isTrue);
      expect(queued.any((row) => row.entityType == 'vehicle'), isTrue);
    },
  );

  test(
    'historical service mileage preserves the current vehicle odometer',
    () async {
      final vehicle = await addVehicle();
      await maintenance.registerService(
        userId: 'user-1',
        vehicle: vehicle,
        draft: ServiceRecordDraft(
          servicedOn: DateTime(2026, 8, 19),
          odometer: 5000,
          totalCost: 0,
          items: const [ServiceLineDraft(name: 'Wash')],
        ),
      );
      expect((await vehicles.getById(vehicle.id))!.mileage, vehicle.mileage);
    },
  );

  test(
    'updateService replaces fields, allows historical odometer, keeps author',
    () async {
      final vehicle = await addVehicle();
      final record = await maintenance.registerService(
        userId: 'user-1',
        vehicle: vehicle,
        draft: ServiceRecordDraft(
          servicedOn: DateTime(2026, 8, 19),
          odometer: 12000,
          totalCost: 85,
          items: [ServiceLineDraft(name: 'Oil Change', lineCost: 85)],
        ),
      );

      final updated = await maintenance.updateService(
        userId: 'user-2',
        vehicle: vehicle,
        serviceRecordId: record.id,
        draft: ServiceRecordDraft(
          servicedOn: DateTime(2026, 8, 19),
          odometer: 9000,
          totalCost: 95,
          notes: 'edited',
          items: [ServiceLineDraft(name: 'Oil Change 5w30', lineCost: 95)],
        ),
      );

      expect(updated.totalCost, 95);
      expect(updated.odometer, 9000);
      expect(updated.createdBy, 'user-1');

      final history = await maintenance.watchHistory(vehicle.id).first;
      expect(history, hasLength(1));
      expect(history.single.notes, 'edited');
      expect(history.single.items, hasLength(1));
      expect(history.single.items.single.name, 'Oil Change 5w30');

      final updatedVehicle = await vehicles.getById(vehicle.id);
      expect(updatedVehicle?.mileage, 12000);

      final queued = await db.select(db.outboxEntries).get();
      final recordEntries = queued
          .where(
            (row) =>
                row.entityType == 'service_record' && row.entityId == record.id,
          )
          .toList();
      expect(recordEntries, isNotEmpty);
      expect(recordEntries.last.payload, contains('Oil Change 5w30'));
    },
  );

  test('updateService bumps vehicle mileage when odometer increases', () async {
    final vehicle = await addVehicle();
    final record = await maintenance.registerService(
      userId: 'user-1',
      vehicle: vehicle,
      draft: ServiceRecordDraft(
        servicedOn: DateTime(2026, 9, 1),
        odometer: 11000,
        totalCost: 0,
        items: [ServiceLineDraft(name: 'Wash')],
      ),
    );

    final updated = await maintenance.updateService(
      userId: 'user-1',
      vehicle: vehicle,
      serviceRecordId: record.id,
      draft: ServiceRecordDraft(
        servicedOn: DateTime(2026, 9, 1),
        odometer: 13000,
        totalCost: 0,
        items: [ServiceLineDraft(name: 'Wash')],
      ),
    );

    expect(updated.odometer, 13000);
    final updatedVehicle = await vehicles.getById(vehicle.id);
    expect(updatedVehicle?.mileage, 13000);
  });

  test(
    'suggested reminders save explicit user targets and intervals',
    () async {
      final vehicle = await addVehicle();
      await maintenance.addPlanItem(
        userId: 'user-1',
        vehicle: vehicle,
        draft: const PlanItemDraft(
          name: 'Oil Change',
          catalogKey: 'oil_change',
          recurring: true,
          intervalDistance: 5000,
          mileage: 33000,
        ),
      );
      final plan = await maintenance.watchPlan(vehicle.id).first;
      expect(plan, hasLength(1));
      expect(plan.single.catalogKey, 'oil_change');
      expect(plan.single.intervalDistance, 5000);
      expect(plan.single.nextDueMileage, 33000);
    },
  );

  test('active catalog reminders cannot be duplicated', () async {
    final vehicle = await addVehicle();
    const draft = PlanItemDraft(
      name: 'Oil Change',
      recurring: false,
      mileage: 33000,
      catalogKey: 'oil_change',
    );
    final saved = await maintenance.addPlanItem(
      userId: 'user-1',
      vehicle: vehicle,
      draft: draft,
    );
    await expectLater(
      maintenance.addPlanItem(userId: 'user-1', vehicle: vehicle, draft: draft),
      throwsA(isA<MaintenanceValidationFailure>()),
    );
    await maintenance.updatePlanItem(
      userId: 'user-1',
      vehicle: vehicle,
      planItemId: saved.id,
      draft: draft,
    );
    expect(await maintenance.watchPlan(vehicle.id).first, hasLength(1));
  });

  test(
    'calendar recurrence, manual overrides and one-time deletion work offline',
    () async {
      final vehicle = await addVehicle();
      final monthly = await maintenance.addPlanItem(
        userId: 'user-1',
        vehicle: vehicle,
        draft: PlanItemDraft(
          name: 'Oil',
          recurring: true,
          timeCount: 1,
          timeUnit: 'months',
          date: DateTime(2026, 1, 31),
          warningDays: 14,
        ),
      );
      final service = await maintenance.registerService(
        userId: 'user-1',
        vehicle: vehicle,
        draft: ServiceRecordDraft(
          servicedOn: DateTime(2026, 1, 31),
          odometer: null,
          totalCost: 0,
          items: [ServiceLineDraft(name: 'Oil', planItemId: monthly.id)],
        ),
      );
      expect(
        (await maintenance.getPlanItem(monthly.id))!.nextDueOn,
        DateTime(2026, 2, 28),
      );
      expect((await maintenance.getPlanItem(monthly.id))!.warningDays, 14);
      await maintenance.updatePlanItem(
        userId: 'user-1',
        vehicle: vehicle,
        planItemId: monthly.id,
        draft: PlanItemDraft(
          name: 'Oil',
          recurring: true,
          timeCount: 1,
          timeUnit: 'months',
          date: DateTime(2027),
        ),
      );
      await maintenance.updateService(
        userId: 'user-1',
        vehicle: vehicle,
        serviceRecordId: service.id,
        draft: ServiceRecordDraft(
          servicedOn: DateTime(2026, 1, 30),
          odometer: null,
          totalCost: 0,
          items: [ServiceLineDraft(name: 'Oil', planItemId: monthly.id)],
        ),
      );
      expect(
        (await maintenance.getPlanItem(monthly.id))!.nextDueOn,
        DateTime(2027),
      );
      final once = await maintenance.addPlanItem(
        userId: 'user-1',
        vehicle: vehicle,
        draft: PlanItemDraft(
          name: 'Battery',
          recurring: false,
          date: DateTime(2027),
        ),
      );
      final done = await maintenance.registerService(
        userId: 'user-1',
        vehicle: vehicle,
        draft: ServiceRecordDraft(
          servicedOn: DateTime(2026, 2),
          odometer: null,
          totalCost: 0,
          items: [ServiceLineDraft(name: 'Battery', planItemId: once.id)],
        ),
      );
      expect((await maintenance.getPlanItem(once.id))!.enabled, isFalse);
      await maintenance.deleteService(
        userId: 'user-1',
        serviceRecordId: done.id,
      );
      expect((await maintenance.getPlanItem(once.id))!.enabled, isTrue);
      expect(
        (await maintenance.getPlanItem(once.id))!.nextDueOn,
        DateTime(2027),
      );
    },
  );

  test('watchAllPlans lists items across the user garage', () async {
    final first = await addVehicle();
    final second = await vehicles.add(
      userId: 'user-1',
      draft: VehicleDraft(
        name: 'Weekend',
        make: 'Honda',
        model: 'Civic',
        year: 2021,
        licensePlate: 'XYZ789',
        fuelType: FuelType.petrol,
        mileage: 2000,
      ),
    );
    await maintenance.addPlanItem(
      userId: 'user-1',
      vehicle: first,
      draft: const PlanItemDraft(name: 'Oil', recurring: false, mileage: 12000),
    );
    await maintenance.addPlanItem(
      userId: 'user-1',
      vehicle: second,
      draft: const PlanItemDraft(
        name: 'Tires',
        recurring: false,
        mileage: 8000,
      ),
    );

    final items = await maintenance.watchAllPlans('user-1').first;
    expect(items.map((item) => item.name), containsAll(['Oil', 'Tires']));
  });
}

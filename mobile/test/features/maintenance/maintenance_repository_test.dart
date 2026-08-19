import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/domain/maintenance_failure.dart';
import 'package:dco_mobile/features/maintenance/domain/suggested_catalog.dart';
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
  late MaintenanceRepositoryImpl maintenance;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db);
    vehicles = VehicleRepositoryImpl(db: db, outbox: outbox);
    maintenance = MaintenanceRepositoryImpl(db: db, outbox: outbox);
  });

  tearDown(() => db.close());

  Future<Vehicle> addVehicle() {
    return vehicles.add(userId: 'user-1', draft: _vehicleDraft());
  }

  test('ensureDefaultPlan seeds Mileage Update and Routine once', () async {
    final vehicle = await addVehicle();
    await maintenance.ensureDefaultPlan(userId: 'user-1', vehicle: vehicle);
    await maintenance.ensureDefaultPlan(userId: 'user-1', vehicle: vehicle);

    final plan = await maintenance.watchPlan(vehicle.id).first;
    expect(plan, hasLength(2));
    expect(plan.map((item) => item.name), containsAll(['Mileage Update', 'Routine']));
    expect(plan.every((item) => item.recurring), isTrue);
  });

  test('registering a service writes history, advances recurring due, and bumps mileage', () async {
    final vehicle = await addVehicle();
    final item = await maintenance.addPlanItem(
      userId: 'user-1',
      vehicle: vehicle,
      draft: const PlanItemDraft(
        name: 'Oil Change',
        recurring: true,
        intervalDays: 365,
        intervalDistance: 15000,
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
          ServiceLineDraft(name: 'Oil Change', planItemId: item.id, lineCost: 85),
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
  });

  test('service odometer cannot decrease vehicle mileage', () async {
    final vehicle = await addVehicle();
    expect(
      () => maintenance.registerService(
        userId: 'user-1',
        vehicle: vehicle,
        draft: ServiceRecordDraft(
          servicedOn: DateTime(2026, 8, 19),
          odometer: 5000,
          totalCost: 0,
          items: const [ServiceLineDraft(name: 'Wash')],
        ),
      ),
      throwsA(isA<MileageDecreaseFailure>()),
    );
  });

  test('suggested catalog items become user-owned copies', () async {
    final vehicle = await addVehicle();
    final suggestion = SuggestedCatalog.items.firstWhere((item) => item.catalogKey == 'oil_change');
    await maintenance.addSuggestedItem(
      userId: 'user-1',
      vehicle: vehicle,
      suggestion: suggestion,
    );
    await maintenance.addSuggestedItem(
      userId: 'user-1',
      vehicle: vehicle,
      suggestion: suggestion,
    );

    final plan = await maintenance.watchPlan(vehicle.id).first;
    expect(plan, hasLength(1));
    expect(plan.single.catalogKey, 'oil_change');
    expect(plan.single.intervalDistance, 15000);
  });
}

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/fuel/data/repositories/fuel_repository_impl.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/fuel/domain/fuel_failure.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleDraft _petrolDraft() {
  return const VehicleDraft(
    name: 'Daily',
    make: 'Toyota',
    model: 'Camry',
    year: 2022,
    licensePlate: 'ABC123',
    fuelType: FuelType.petrol,
    mileage: 10000,
  );
}

VehicleDraft _evDraft() {
  return const VehicleDraft(
    name: 'EV',
    make: 'Tesla',
    model: 'Model 3',
    year: 2023,
    licensePlate: 'EV1234',
    fuelType: FuelType.electric,
    mileage: 4000,
  );
}

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl vehicles;
  late FuelRepositoryImpl fuel;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db);
    vehicles = VehicleRepositoryImpl(db: db, outbox: outbox);
    fuel = FuelRepositoryImpl(db: db, outbox: outbox);
  });

  tearDown(() => db.close());

  test('ensureDefaultFuelTypes seeds liquid and electric types once', () async {
    await fuel.ensureDefaultFuelTypes('user-1');
    await fuel.ensureDefaultFuelTypes('user-1');

    final types = await fuel.watchFuelTypes('user-1').first;
    expect(types.map((type) => type.name), containsAll(['Petrol', 'Diesel', 'Electricity']));
    expect(types.where((type) => type.kind == FuelCatalogKind.liquid), hasLength(2));
    expect(types.where((type) => type.kind == FuelCatalogKind.electric), hasLength(1));
  });

  test('duplicate fuel type name on the same account is rejected', () async {
    await fuel.addFuelType(
      userId: 'user-1',
      draft: const FuelCatalogTypeDraft(name: 'Petrol', kind: FuelCatalogKind.liquid, unit: 'L'),
    );
    expect(
      () => fuel.addFuelType(
        userId: 'user-1',
        draft: const FuelCatalogTypeDraft(name: 'petrol', kind: FuelCatalogKind.liquid, unit: 'L'),
      ),
      throwsA(isA<DuplicateFuelTypeNameFailure>()),
    );
  });

  test('add refuel writes a log, snapshots the type, and queues outbox', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _petrolDraft());
    await fuel.ensureDefaultFuelTypes('user-1');
    final petrol = (await fuel.watchFuelTypes('user-1', kind: FuelCatalogKind.liquid).first)
        .firstWhere((type) => type.name == 'Petrol');

    final log = await fuel.addLog(
      userId: 'user-1',
      vehicleId: vehicle.id,
      kind: FuelLogKind.refuel,
      draft: FuelLogDraft(
        loggedOn: DateTime(2026, 8, 20),
        fuelTypeId: petrol.id,
        amount: 40,
        cost: 52.5,
      ),
    );

    expect(log.kind, FuelLogKind.refuel);
    expect(log.fuelTypeName, 'Petrol');
    expect(log.unit, 'L');
    expect(log.amount, 40);
    expect(log.cost, 52.5);

    final queued = await db.select(db.outboxEntries).get();
    expect(queued.any((row) => row.entityType == 'fuel_log' && row.entityId == log.id), isTrue);
  });

  test('electric vehicles log charge against electric types', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _evDraft());
    await fuel.ensureDefaultFuelTypes('user-1');
    final electricity = (await fuel.watchFuelTypes('user-1', kind: FuelCatalogKind.electric).first).single;

    final log = await fuel.addLog(
      userId: 'user-1',
      vehicleId: vehicle.id,
      kind: FuelLogKind.charge,
      draft: FuelLogDraft(
        loggedOn: DateTime(2026, 8, 20),
        fuelTypeId: electricity.id,
        amount: 32,
        cost: 8,
      ),
    );

    expect(log.kind, FuelLogKind.charge);
    expect(log.unit, 'kWh');
    expect(FuelLogKind.forVehicleFuelType(vehicle.fuelType.storage), FuelLogKind.charge);

    final logs = await fuel.watchLogs(vehicleId: vehicle.id, kind: FuelLogKind.charge).first;
    expect(logs, hasLength(1));
    final refuels = await fuel.watchLogs(vehicleId: vehicle.id, kind: FuelLogKind.refuel).first;
    expect(refuels, isEmpty);
  });

  test('refuel cannot use an electric catalog type', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _petrolDraft());
    await fuel.ensureDefaultFuelTypes('user-1');
    final electricity = (await fuel.watchFuelTypes('user-1', kind: FuelCatalogKind.electric).first).single;

    expect(
      () => fuel.addLog(
        userId: 'user-1',
        vehicleId: vehicle.id,
        kind: FuelLogKind.refuel,
        draft: FuelLogDraft(
          loggedOn: DateTime(2026, 8, 20),
          fuelTypeId: electricity.id,
          amount: 10,
          cost: 1,
        ),
      ),
      throwsA(isA<FuelTypeKindMismatchFailure>()),
    );
  });

  test('update log changes amount and cost and keeps identity', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _petrolDraft());
    await fuel.ensureDefaultFuelTypes('user-1');
    final petrol = (await fuel.watchFuelTypes('user-1', kind: FuelCatalogKind.liquid).first)
        .firstWhere((type) => type.name == 'Petrol');
    final log = await fuel.addLog(
      userId: 'user-1',
      vehicleId: vehicle.id,
      kind: FuelLogKind.refuel,
      draft: FuelLogDraft(
        loggedOn: DateTime(2026, 8, 1),
        fuelTypeId: petrol.id,
        amount: 30,
        cost: 40,
      ),
    );

    final updated = await fuel.updateLog(
      userId: 'user-1',
      logId: log.id,
      kind: FuelLogKind.refuel,
      draft: FuelLogDraft(
        loggedOn: DateTime(2026, 8, 2),
        fuelTypeId: petrol.id,
        amount: 35,
        cost: 48,
      ),
    );

    expect(updated.id, log.id);
    expect(updated.amount, 35);
    expect(updated.cost, 48);
    expect(updated.loggedOn, DateTime(2026, 8, 2));
  });
}

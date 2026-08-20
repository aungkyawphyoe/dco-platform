import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/parts/data/repositories/parts_repository_impl.dart';
import 'package:dco_mobile/features/parts/domain/entities/part.dart';
import 'package:dco_mobile/features/parts/domain/part_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleDraft _vehicleDraft() {
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

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl vehicles;
  late PartsRepositoryImpl parts;
  late MaintenanceRepositoryImpl maintenance;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db);
    vehicles = VehicleRepositoryImpl(db: db, outbox: outbox);
    parts = PartsRepositoryImpl(db: db, outbox: outbox);
    maintenance = MaintenanceRepositoryImpl(db: db, outbox: outbox);
  });

  tearDown(() => db.close());

  test('add writes a part and queues outbox', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    final part = await parts.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: const PartDraft(name: 'Oil filter', brand: 'Bosch', partNumber: 'OF-1'),
    );

    final catalog = await parts.watchForVehicle(vehicle.id).first;
    expect(catalog, hasLength(1));
    expect(catalog.single.id, part.id);
    expect(catalog.single.brand, 'Bosch');

    final queued = await db.select(db.outboxEntries).get();
    expect(queued.any((row) => row.entityType == 'part' && row.entityId == part.id), isTrue);
  });

  test('duplicate name on the same vehicle is rejected', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    await parts.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: const PartDraft(name: 'Oil filter'),
    );
    expect(
      () => parts.add(
        userId: 'user-1',
        vehicleId: vehicle.id,
        draft: const PartDraft(name: 'oil filter'),
      ),
      throwsA(isA<DuplicatePartNameFailure>()),
    );
  });

  test('update changes fields and keeps identity', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    final part = await parts.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: const PartDraft(name: 'Oil filter'),
    );

    final updated = await parts.update(
      userId: 'user-1',
      partId: part.id,
      draft: const PartDraft(name: 'Cabin filter', notes: 'Behind glovebox'),
    );

    expect(updated.id, part.id);
    expect(updated.name, 'Cabin filter');
    expect(updated.notes, 'Behind glovebox');
  });

  test('registering a service stores assigned parts', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    final part = await parts.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: const PartDraft(name: 'Oil filter'),
    );

    final record = await maintenance.registerService(
      userId: 'user-1',
      vehicle: vehicle,
      draft: ServiceRecordDraft(
        servicedOn: DateTime(2026, 8, 20),
        odometer: 11000,
        totalCost: 40,
        items: const [ServiceLineDraft(name: 'Oil Change')],
        parts: [AssignedPartDraft(partId: part.id, name: part.name)],
      ),
    );

    expect(record.parts, hasLength(1));
    expect(record.parts.single.partId, part.id);
    expect(record.parts.single.name, 'Oil filter');

    final loaded = await maintenance.getServiceRecord(record.id);
    expect(loaded?.parts.single.name, 'Oil filter');
  });
}

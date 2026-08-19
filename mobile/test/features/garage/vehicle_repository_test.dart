import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleDraft _draft({
  String name = 'Daily',
  String plate = 'ABC123',
  String? vin,
  double mileage = 1000,
}) {
  return VehicleDraft(
    name: name,
    make: 'Toyota',
    model: 'Camry',
    year: 2022,
    licensePlate: plate,
    fuelType: FuelType.petrol,
    mileage: mileage,
    vin: vin,
  );
}

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = VehicleRepositoryImpl(db: db, outbox: OutboxWriter(db));
  });

  tearDown(() => db.close());

  test('add writes vehicle, sets active, and queues outbox', () async {
    const userId = 'user-1';
    final vehicle = await repo.add(userId: userId, draft: _draft());

    final garage = await repo.watchGarage(userId).first;
    expect(garage, hasLength(1));
    expect(garage.first.id, vehicle.id);

    final active = await repo.watchActive(userId).first;
    expect(active?.id, vehicle.id);

    final queued = await db.select(db.outboxEntries).get();
    expect(queued, hasLength(1));
    expect(queued.single.entityType, 'vehicle');
    expect(queued.single.op, 'upsert');
    expect(queued.single.entityId, vehicle.id);
  });

  test('duplicate plate is rejected', () async {
    const userId = 'user-1';
    await repo.add(userId: userId, draft: _draft(plate: 'ABC123'));
    expect(
      () => repo.add(userId: userId, draft: _draft(name: 'Other', plate: 'abc123')),
      throwsA(isA<DuplicatePlateFailure>()),
    );
  });

  test('duplicate VIN is rejected', () async {
    const userId = 'user-1';
    await repo.add(userId: userId, draft: _draft(vin: '1HGBH41JXMN109186'));
    expect(
      () => repo.add(
        userId: userId,
        draft: _draft(name: 'Other', plate: 'XYZ789', vin: '1hgbh41jxmn109186'),
      ),
      throwsA(isA<DuplicateVinFailure>()),
    );
  });

  test('mileage cannot decrease', () async {
    const userId = 'user-1';
    final vehicle = await repo.add(userId: userId, draft: _draft(mileage: 5000));
    expect(
      () => repo.update(
        userId: userId,
        vehicleId: vehicle.id,
        draft: _draft(mileage: 4000),
      ),
      throwsA(isA<MileageDecreaseFailure>()),
    );
  });
}

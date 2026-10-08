import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_failure.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/entities/vehicle_share.dart';
import 'package:drift/drift.dart' show Value;
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

  test('watchActive takes access level from the active share row', () async {
    const owner = 'owner-1';
    const member = 'member-1';
    const vehicleId = 'vehicle-shared-1';
    final now = DateTime(2026, 10, 8, 12);

    // Local vehicle row with a stale denormalized permission (owner upgraded
    // the share after the row was first stamped, or it was never stamped).
    await db.into(db.vehicleRecords).insert(
          VehicleRecordsCompanion.insert(
            id: vehicleId,
            userId: owner,
            name: 'Shared Car',
            make: 'Toyota',
            model: 'Corolla',
            year: 2021,
            licensePlate: 'SHR001',
            fuelType: 'petrol',
            mileage: 5000,
            updatedAt: now,
            createdAt: now,
            source: const Value('shared'),
            permission: const Value('view'),
          ),
        );
    await db.into(db.vehicleShareRecords).insert(
          VehicleShareRecordsCompanion.insert(
            id: 'share-1',
            vehicleId: vehicleId,
            userId: member,
            grantedBy: const Value(owner),
            accessLevel: 'add_edit_own',
            status: const Value('active'),
            createdAt: now,
          ),
        );
    await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            userId: member,
            activeVehicleId: const Value(vehicleId),
          ),
        );

    final active = await repo.watchActive(member).first;
    expect(active, isNotNull);
    expect(active!.accessLevel, ShareAccessLevel.addEditOwn,
        reason: 'the share mirror must win over the stale row permission');
    expect(active.source, VehicleSource.shared);

    final byId = await repo.watchById(vehicleId, userId: member).first;
    expect(byId?.accessLevel, ShareAccessLevel.addEditOwn,
        reason: 'vehicle detail gating must see the same level');
  });
}

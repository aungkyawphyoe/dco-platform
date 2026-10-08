import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/change_applier.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the exact change payloads the backend emits for a shared
/// vehicle (dumped from backend/test/_dump.test.ts) and asserts the
/// sharee's local state after applying them in sequence.
void main() {
  late AppDatabase db;
  late ChangeApplier applier;

  const owner = '2a85769d-67c2-4ddc-b7db-1a4c0f7582d3';
  const member = 'e07d2ca8-3a9b-4b8e-953d-563cb31c94a4';
  const vehicleId = '8b2696e3-6d2d-414b-b98e-a5ea592cadcc';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    applier = ChangeApplier(db);
  });

  tearDown(() => db.close());

  SyncChange change(
    String type,
    String id,
    String op,
    Map<String, dynamic> payload,
    String serverTs,
  ) {
    return SyncChange(
      entityType: type,
      entityId: id,
      op: SyncChangeOp.parse(op),
      payload: payload,
      serverTs: DateTime.parse(serverTs),
    );
  }

  final fullVehicle = {
    'id': vehicleId,
    'vin': '8b2696e36d2d414bb',
    'make': 'Toyota',
    'name': 'Dump Car',
    'year': 2021,
    'color': null,
    'model': 'Corolla',
    'mileage': 6500,
    'user_id': owner,
    'archived': false,
    'nickname': null,
    'fuel_type': 'petrol',
    'updated_at': '2026-10-08T05:23:14.526Z',
    'archived_at': null,
    'mileage_unit': 'km',
    'license_plate': 'DMP8b26',
    'purchase_date': null,
    'photo_media_id': null,
    'purchase_price': null,
    'next_maintenance': null,
  };

  test('sharee applies seeded history then trailing mileage fan-out', () async {
    // Seeded accept payload: full vehicle.
    await applier.apply(
      change('vehicle', vehicleId, 'upsert', fullVehicle,
          '2026-10-08T05:23:14.547Z'),
      userId: member,
    );
    // Share stamps source/permission.
    await applier.apply(
      change(
        'vehicle_share',
        '8d5eea65-774f-4ddd-bbc5-e80963f319e1',
        'upsert',
        {
          'id': '8d5eea65-774f-4ddd-bbc5-e80963f319e1',
          'status': 'active',
          'user_id': member,
          'granted_by': owner,
          'vehicle_id': vehicleId,
          'accepted_at': '2026-10-08T05:23:14.546Z',
          'access_level': 'add_edit_own',
        },
        '2026-10-08T05:23:14.548Z',
      ),
      userId: member,
    );

    // Owner logs a service -> mileage fan-out is a PARTIAL payload.
    await applier.apply(
      change('vehicle', vehicleId, 'upsert',
          {'id': vehicleId, 'name': 'Dump Car', 'mileage': 7000},
          '2026-10-08T05:23:14.566Z'),
      userId: member,
    );

    final row = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals(vehicleId)))
        .getSingle();
    expect(row.mileage, 7000, reason: 'mileage fan-out must lift mileage');
    expect(row.userId, owner, reason: 'partial payload must not reassign owner');
    expect(row.make, 'Toyota', reason: 'partial payload must not wipe make');
    expect(row.model, 'Corolla', reason: 'partial payload must not wipe model');
    expect(row.licensePlate, 'DMP8b26',
        reason: 'partial payload must not wipe plate');
    expect(row.mileageUnit, 'km',
        reason: 'partial payload must not flip mileage unit');
    expect(row.source, 'shared', reason: 'share stamp must survive');
    expect(row.permission, 'add_edit_own',
        reason: 'share permission must survive');
  });

  test('sharee applies owner rename after a trailing partial payload',
      () async {
    await applier.apply(
      change('vehicle', vehicleId, 'upsert', fullVehicle,
          '2026-10-08T05:23:14.547Z'),
      userId: member,
    );

    // Mileage fan-out first (partial), then a full rename payload.
    await applier.apply(
      change('vehicle', vehicleId, 'upsert',
          {'id': vehicleId, 'name': 'Dump Car', 'mileage': 7000},
          '2026-10-08T05:23:14.566Z'),
      userId: member,
    );
    await applier.apply(
      change('vehicle', vehicleId, 'upsert', {
        ...fullVehicle,
        'name': 'Renamed',
        'mileage': 7000,
        'updated_at': '2026-10-08T05:23:14.572Z',
      }, '2026-10-08T05:23:14.575Z'),
      userId: member,
    );

    final row = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals(vehicleId)))
        .getSingle();
    expect(row.name, 'Renamed');
    expect(row.make, 'Toyota');
    expect(row.licensePlate, 'DMP8b26');
    expect(row.mileageUnit, 'km');
    expect(row.userId, owner);
    expect(row.mileage, 7000);
  });

  test('service record from owner appears on sharee device', () async {
    await applier.apply(
      change(
        'service_record',
        'a68fb246-59e1-4af1-9174-4f6c2e738561',
        'upsert',
        {
          'id': 'a68fb246-59e1-4af1-9174-4f6c2e738561',
          'items': [
            {
              'id': '5d91155c-7865-4fe7-906f-f4fea9cf53da',
              'name': 'Tires',
              'line_cost': 90,
              'plan_item_id': null,
            },
          ],
          'notes': null,
          'parts': <Map<String, dynamic>>[],
          'odometer': 7000,
          'created_by': owner,
          'total_cost': 90,
          'vehicle_id': vehicleId,
          'serviced_on': '2026-09-01',
          'workshop_name': null,
          'receipt_media_id': null,
        },
        '2026-10-08T05:23:14.569Z',
      ),
      userId: member,
    );

    final row = await (db.select(db.serviceRecordRows)
          ..where((r) => r.id.equals('a68fb246-59e1-4af1-9174-4f6c2e738561')))
        .getSingle();
    expect(row.title, 'Tires');
    expect(row.vehicleId, vehicleId);
    expect(row.createdBy, owner);
  });
}

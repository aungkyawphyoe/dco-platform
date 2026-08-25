import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/change_applier.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ChangeApplier applier;

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

  const vehiclePayload = {
    'id': 'v1',
    'user_id': 'u1',
    'name': 'Daily',
    'make': 'Toyota',
    'model': 'Camry',
    'year': 2022,
    'license_plate': 'ABC123',
    'vin': null,
    'color': null,
    'fuel_type': 'petrol',
    'mileage': 1500.0,
    'mileage_unit': 'mi',
    'purchase_date': null,
    'purchase_price': null,
    'photo_media_id': null,
    'archived': false,
    'archived_at': null,
    'updated_at': '2026-01-02T10:00:00.000Z',
  };

  test('vehicle upsert inserts a row', () async {
    await applier.apply(
      change('vehicle', 'v1', 'upsert', vehiclePayload, '2026-01-02T10:00:00.000Z'),
      userId: 'u1',
    );
    final row = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals('v1')))
        .getSingle();
    expect(row.name, 'Daily');
    expect(row.mileage, 1500);
    expect(row.archived, false);
  });

  test('vehicle mileage never decreases even when remote is newer', () async {
    await db.into(db.vehicleRecords).insert(
      VehicleRecordsCompanion.insert(
        id: 'v1',
        userId: 'u1',
        name: 'Daily',
        make: 'Toyota',
        model: 'Camry',
        year: 2022,
        licensePlate: 'ABC123',
        fuelType: 'petrol',
        mileage: 2000,
        updatedAt: DateTime.parse('2026-01-03T09:00:00.000Z'),
        createdAt: DateTime.parse('2026-01-01T09:00:00.000Z'),
      ),
    );

    await applier.apply(
      change('vehicle', 'v1', 'upsert', {
        ...vehiclePayload,
        'mileage': 1200.0,
        'updated_at': '2026-01-04T10:00:00.000Z',
      }, '2026-01-04T10:00:00.000Z'),
      userId: 'u1',
    );
    final row = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals('v1')))
        .getSingle();
    expect(row.mileage, 2000);
    expect(
      row.updatedAt.isAtSameMomentAs(DateTime.parse('2026-01-04T10:00:00.000Z')),
      true,
    );
  });

  test('stale remote cannot roll back vehicle fields but can lift mileage', () async {
    await db.into(db.vehicleRecords).insert(
      VehicleRecordsCompanion.insert(
        id: 'v1',
        userId: 'u1',
        name: 'Renamed',
        make: 'Toyota',
        model: 'Camry',
        year: 2022,
        licensePlate: 'ABC123',
        fuelType: 'petrol',
        mileage: 1800,
        updatedAt: DateTime.parse('2026-01-05T09:00:00.000Z'),
        createdAt: DateTime.parse('2026-01-01T09:00:00.000Z'),
      ),
    );

    await applier.apply(
      change('vehicle', 'v1', 'upsert', vehiclePayload, '2026-01-02T10:00:00.000Z'),
      userId: 'u1',
    );
    final row = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals('v1')))
        .getSingle();
    expect(row.name, 'Renamed');
    expect(row.mileage, 1800);
  });

  test('archive wins over a later edit', () async {
    await db.into(db.vehicleRecords).insert(
      VehicleRecordsCompanion.insert(
        id: 'v1',
        userId: 'u1',
        name: 'Daily',
        make: 'Toyota',
        model: 'Camry',
        year: 2022,
        licensePlate: 'ABC123',
        fuelType: 'petrol',
        mileage: 1000,
        updatedAt: DateTime.parse('2026-01-01T09:00:00.000Z'),
        createdAt: DateTime.parse('2026-01-01T09:00:00.000Z'),
      ),
    );
    await applier.apply(
      change('vehicle', 'v1', 'archive', {'id': 'v1'}, '2026-01-02T09:00:00.000Z'),
      userId: 'u1',
    );
    await applier.apply(
      change('vehicle', 'v1', 'upsert', {
        ...vehiclePayload,
        'updated_at': '2026-01-06T09:00:00.000Z',
      }, '2026-01-06T09:00:00.000Z'),
      userId: 'u1',
    );

    final row = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals('v1')))
        .getSingle();
    expect(row.archived, true);
  });

  test('expense upsert replaces child parts and delete removes them', () async {
    await applier.apply(
      change('expense', 'e1', 'upsert', {
        'id': 'e1',
        'vehicle_id': 'v1',
        'category': 'parts',
        'amount': 89.99,
        'incurred_on': '2026-02-01',
        'notes': null,
        'receipt_media_id': null,
        'parts': [
          {'id': 'ep1', 'part_id': 'p1', 'name': 'Oil filter'},
        ],
      }, '2026-02-01T08:00:00.000Z'),
      userId: 'u1',
    );
    var parts = await db.select(db.expensePartRecords).get();
    expect(parts, hasLength(1));
    expect(parts.single.name, 'Oil filter');

    await applier.apply(
      change('expense', 'e1', 'upsert', {
        'id': 'e1',
        'vehicle_id': 'v1',
        'category': 'parts',
        'amount': 99.99,
        'incurred_on': '2026-02-01',
        'parts': <Map<String, dynamic>>[],
      }, '2026-02-02T08:00:00.000Z'),
      userId: 'u1',
    );
    var row = await (db.select(db.expenseRecords)..where((r) => r.id.equals('e1')))
        .getSingleOrNull();
    expect(row!.amount, 99.99);
    parts = await db.select(db.expensePartRecords).get();
    expect(parts, isEmpty);

    await applier.apply(
      change('expense', 'e1', 'delete', {}, '2026-02-03T08:00:00.000Z'),
      userId: 'u1',
    );
    final deleted = await (db.select(db.expenseRecords)
          ..where((r) => r.id.equals('e1')))
        .getSingleOrNull();
    expect(deleted, isNull);
  });

  test('notification upsert and stale replay are handled', () async {
    await applier.apply(
      change('notification', 'n1', 'upsert', {
        'id': 'n1',
        'vehicle_id': 'v1',
        'plan_item_id': null,
        'title': 'Oil change due',
        'body': 'Due in 200 mi',
        'status': 'unread',
        'due_reason': 'both',
        'created_at': '2026-02-01T08:00:00.000Z',
      }, '2026-02-01T08:00:00.000Z'),
      userId: 'u1',
    );
    var row = await (db.select(db.notificationRecords)
          ..where((r) => r.id.equals('n1')))
        .getSingle();
    expect(row.status, 'unread');

    await applier.apply(
      change('notification', 'n1', 'upsert', {
        'id': 'n1',
        'title': 'Oil change due',
        'body': 'Due in 200 mi',
        'status': 'read',
      }, '2026-02-05T08:00:00.000Z'),
      userId: 'u1',
    );
    row = await (db.select(db.notificationRecords)..where((r) => r.id.equals('n1')))
        .getSingle();
    expect(row.status, 'read');
  });
}

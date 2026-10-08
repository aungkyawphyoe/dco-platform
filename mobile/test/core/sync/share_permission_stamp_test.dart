import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/change_applier.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:dco_mobile/features/garage/data/mappers/vehicle_mapper.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_access.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the sharee access-level propagation bugs:
/// the vehicle row's denormalized `permission`/`source` must track the
/// local `vehicle_shares` mirror — on initial accept, on later owner
/// level changes, and regardless of change ordering within a pull.
void main() {
  late AppDatabase db;
  late ChangeApplier applier;

  const owner = 'owner-uuid';
  const member = 'member-uuid';
  const vehicleId = 'vehicle-uuid';
  const shareId = 'share-uuid';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    applier = ChangeApplier(db);
  });

  tearDown(() => db.close());

  SyncChange change(
    String type,
    String id,
    Map<String, dynamic> payload,
    String serverTs, {
    String op = 'upsert',
  }) {
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
    'name': 'Shared Car',
    'make': 'Toyota',
    'model': 'Corolla',
    'year': 2021,
    'license_plate': 'SHR001',
    'user_id': owner,
    'archived': false,
    'fuel_type': 'petrol',
    'mileage': 5000,
    'mileage_unit': 'km',
    'updated_at': '2026-10-08T05:23:14.526Z',
  };

  Map<String, dynamic> sharePayload(String accessLevel) => {
        'id': shareId,
        'status': 'active',
        'user_id': member,
        'granted_by': owner,
        'vehicle_id': vehicleId,
        'accepted_at': '2026-10-08T05:23:14.546Z',
        'access_level': accessLevel,
      };

  Future<VehicleRecord> vehicleRow() {
    return (db.select(db.vehicleRecords)..where((r) => r.id.equals(vehicleId)))
        .getSingle();
  }

  test('owner upgrading access level re-stamps the vehicle permission',
      () async {
    await applier.apply(
      change('vehicle', vehicleId, fullVehicle, '2026-10-08T05:23:14.547Z'),
      userId: member,
    );
    await applier.apply(
      change('vehicle_share', shareId, sharePayload('view'),
          '2026-10-08T05:23:14.548Z'),
      userId: member,
    );

    var row = await vehicleRow();
    expect(row.permission, 'view');
    expect(row.source, 'shared');

    // Owner later switches the share to "Add & edit own" (PATCH records a
    // fresh vehicle_share change into the sharee's feed).
    await applier.apply(
      change('vehicle_share', shareId, sharePayload('add_edit_own'),
          '2026-10-08T06:00:00.000Z'),
      userId: member,
    );

    row = await vehicleRow();
    expect(row.permission, 'add_edit_own',
        reason: 'level change must re-stamp the vehicle permission');
    expect(row.source, 'shared');

    final vehicle = vehicleFromDrift(row);
    final access = VehicleAccess.of(vehicle, member);
    expect(access.canCreate, isTrue,
        reason: 'sharee with add_edit_own must be able to create records');
  });

  test('vehicle insert picks up permission from an already-applied share',
      () async {
    // Share change arrives before the vehicle row exists (pagination split
    // or earlier local wipe).
    await applier.apply(
      change('vehicle_share', shareId, sharePayload('add_edit_own'),
          '2026-10-08T05:23:14.547Z'),
      userId: member,
    );

    await applier.apply(
      change('vehicle', vehicleId, fullVehicle, '2026-10-08T05:23:14.548Z'),
      userId: member,
    );

    final row = await vehicleRow();
    expect(row.permission, 'add_edit_own',
        reason: 'vehicle insert must stamp from the local share mirror');
    expect(row.source, 'shared');

    final access = VehicleAccess.of(vehicleFromDrift(row), member);
    expect(access.canCreate, isTrue);
    expect(access.canEditRecord(member), isTrue);
    expect(access.canEditRecord(owner), isFalse);
  });

}

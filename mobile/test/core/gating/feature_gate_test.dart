import 'dart:async';

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/gating/feature_gate.dart';
import 'package:dco_mobile/core/gating/license_models.dart';
import 'package:dco_mobile/core/gating/license_store.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_license.dart';

void main() {
  late AppDatabase db;
  late MemoryLicenseStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = MemoryLicenseStore();
  });

  tearDown(() => db.close());

  Future<void> insertVehicle(String id, {String userId = 'u1'}) {
    return db.into(db.vehicleRecords).insert(
          VehicleRecordsCompanion.insert(
            id: id,
            userId: userId,
            name: 'Vehicle $id',
            make: 'Toyota',
            model: 'Camry',
            year: 2022,
            licensePlate: id.toUpperCase(),
            fuelType: 'petrol',
            mileage: 100,
            updatedAt: DateTime.now().toUtc(),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> archiveVehicle(String id) {
    return (db.update(db.vehicleRecords)..where((r) => r.id.equals(id))).write(
      VehicleRecordsCompanion(
        archived: const Value(true),
        archivedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> insertShare(
    String id, {
    required String vehicleId,
    String status = 'active',
  }) {
    return db.into(db.vehicleShareRecords).insert(
          VehicleShareRecordsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            userId: 'u2',
            accessLevel: 'view',
            status: Value(status),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  ProviderContainer createContainer({
    required MintedLicense license,
    String userId = 'u1',
  }) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(userId),
        licenseStoreProvider.overrideWithValue(store),
        licenseKeyringProvider.overrideWith(
          (ref) async => [
            LicenseKeyringEntry(kid: 'test-key', alg: 'EdDSA', x: license.x),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Polls until the gate is settled and (optionally) reflects a
  /// expected live count — the snapshot only recomputes after the
  /// Drift stream emits, so tests must wait for the new instance.
  Future<FeatureGateSnapshot> awaitGate(
    ProviderContainer container, {
    bool Function(FeatureGateSnapshot gate)? until,
  }) async {
    for (var i = 0; i < 200; i++) {
      final gate = container.read(featureGateProvider);
      if (gate != null && (until == null || until(gate))) return gate;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('feature gate never settled with the expected counts');
  }

  test('free plan: one active vehicle fills the slot, archiving frees it', () async {
    final license = await mintLicense(
      planId: 'free',
      vehicleLimit: 1,
      sharingLimit: 1,
      issuedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    await store.writeLicense('u1', license.jwt);
    final container = createContainer(license: license);

    expect((await awaitGate(container)).canCreateVehicle, isTrue);

    await insertVehicle('v1');
    final full = await awaitGate(container, until: (g) => g.vehicleCount == 1);
    expect(full.canCreateVehicle, isFalse);

    await archiveVehicle('v1');
    final emptied = await awaitGate(container, until: (g) => g.vehicleCount == 0);
    expect(emptied.canCreateVehicle, isTrue);
  });

  test('lite plan allows up to its higher cap, then blocks', () async {
    final license = await mintLicense(
      planId: 'lite',
      vehicleLimit: 3,
      sharingLimit: 3,
      issuedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    await store.writeLicense('u1', license.jwt);
    final container = createContainer(license: license);

    await insertVehicle('v1');
    await insertVehicle('v2');
    final two = await awaitGate(container, until: (g) => g.vehicleCount == 2);
    expect(two.canCreateVehicle, isTrue);

    await insertVehicle('v3');
    final gate = await awaitGate(container, until: (g) => g.vehicleCount == 3);
    expect(gate.canCreateVehicle, isFalse);
    expect(gate.nextVehiclePlan?.name, 'Standard');
    expect(gate.nextVehiclePlan?.limit, 10);
  });

  test('null vehicle_limit means unlimited (standard/fleet)', () async {
    final license = await mintLicense(
      planId: 'standard',
      vehicleLimit: null,
      sharingLimit: null,
      issuedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    await store.writeLicense('u1', license.jwt);
    final container = createContainer(license: license);

    for (var i = 0; i < 5; i++) {
      await insertVehicle('v$i');
    }
    final gate = await awaitGate(container, until: (g) => g.vehicleCount == 5);
    expect(gate.canCreateVehicle, isTrue);
  });

  test('share slots count only active shares of owned vehicles', () async {
    final license = await mintLicense(
      planId: 'free',
      vehicleLimit: 1,
      sharingLimit: 1,
      issuedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    await store.writeLicense('u1', license.jwt);
    final container = createContainer(license: license);
    await insertVehicle('v1');

    await insertShare('s1', vehicleId: 'v1', status: 'pending');
    final pendingOnly = await awaitGate(container);
    expect(pendingOnly.canCreateShare, isTrue);

    await (db.update(db.vehicleShareRecords)..where((r) => r.id.equals('s1')))
        .write(const VehicleShareRecordsCompanion(status: Value('active')));
    final active = await awaitGate(container, until: (g) => g.activeShareCount == 1);
    expect(active.canCreateShare, isFalse);

    await (db.update(db.vehicleShareRecords)..where((r) => r.id.equals('s1')))
        .write(const VehicleShareRecordsCompanion(status: Value('revoked')));
    final revoked = await awaitGate(container, until: (g) => g.activeShareCount == 0);
    expect(revoked.canCreateShare, isTrue);
  });

  test('hydration never settles → gate stays null (deny by default)', () async {
    final license = await mintLicense();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
        licenseStoreProvider.overrideWithValue(store),
        licenseKeyringProvider.overrideWith(
          (ref) => Completer<List<LicenseKeyringEntry>>().future,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(featureGateProvider), isNull);
    expect(license.jwt, isNotEmpty);
  });

  test('claims fall back to free when no license is stored', () async {
    final license = await mintLicense(); // keyring entry only; nothing stored
    final container = createContainer(license: license);

    final gate = await awaitGate(container);
    expect(gate.claims.planId, 'free');
    expect(gate.vehicleLimit, 1);
    expect(gate.canCreateVehicle, isTrue);
    await insertVehicle('v1');
    final full = await awaitGate(container, until: (g) => g.vehicleCount == 1);
    expect(full.canCreateVehicle, isFalse);
  });
}

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/network/api_error.dart';
import 'package:dco_mobile/features/auth/data/datasources/profile_remote_datasource.dart';
import 'package:dco_mobile/features/auth/data/repositories/profile_repository_impl.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProfileRemoteDataSource implements ProfileRemoteDataSource {
  final recordedPatches = <Map<String, dynamic>>[];
  Object? updateError;

  @override
  Future<User> get() async {
    return const User(
      id: 'u1',
      email: 'owner@dco.dev',
      role: 'owner',
      plan: 'free',
      status: 'active',
      emailVerified: true,
    );
  }

  @override
  Future<User> update(Map<String, dynamic> patch) async {
    if (updateError != null) throw updateError!;
    recordedPatches.add(patch);
    return get();
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {}
}

void main() {
  late AppDatabase db;
  late FakeProfileRemoteDataSource remote;
  late ProfileRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeProfileRemoteDataSource();
    repo = ProfileRepositoryImpl(remote: remote, db: db);
  });

  tearDown(() => db.close());

  test('update forwards display name and active vehicle', () async {
    await repo.update(displayName: 'Alex', activeVehicleId: 'v1');
    expect(remote.recordedPatches.single, {
      'display_name': 'Alex',
      'active_vehicle_id': 'v1',
    });
  });

  test('pending active vehicle is flushed and cleared on success', () async {
    await repo.markPendingActiveVehicle(userId: 'u1', vehicleId: 'v9');

    await repo.flushPendingActiveVehicle('u1');

    expect(remote.recordedPatches.single['active_vehicle_id'], 'v9');
    final rows = await (db.select(db.appMeta)
          ..where((m) => m.key.equals('pending_active_vehicle:u1')))
        .get();
    expect(rows, isEmpty);
  });

  test('network failure keeps the pending switch for the next retry', () async {
    await repo.markPendingActiveVehicle(userId: 'u1', vehicleId: 'v9');
    remote.updateError = const ApiError(code: 'network', message: 'offline');

    await repo.flushPendingActiveVehicle('u1');

    final row = await (db.select(db.appMeta)
          ..where((m) => m.key.equals('pending_active_vehicle:u1')))
        .getSingle();
    expect(row.value, 'v9');
  });

  test('permanent failure drops the pending switch', () async {
    await repo.markPendingActiveVehicle(userId: 'u1', vehicleId: 'v9');
    remote.updateError = const ApiError(code: 'validation', message: 'gone');

    await repo.flushPendingActiveVehicle('u1');

    final rows = await (db.select(db.appMeta)
          ..where((m) => m.key.equals('pending_active_vehicle:u1')))
        .get();
    expect(rows, isEmpty);
  });
}

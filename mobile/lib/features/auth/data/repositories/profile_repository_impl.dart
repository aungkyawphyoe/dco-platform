// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_error.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required ProfileRemoteDataSource remote,
    required AppDatabase db,
  }) : _remote = remote,
       _db = db;

  final ProfileRemoteDataSource _remote;
  final AppDatabase _db;

  static const _pendingKeyPrefix = 'pending_active_vehicle:';

  @override
  Future<User> get() => _remote.get();

  @override
  Future<User> update({String? displayName, String? activeVehicleId}) {
    return _remote.update({
      'display_name': ?displayName,
      'active_vehicle_id': ?activeVehicleId,
    });
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) {
    return _remote.registerDeviceToken(token: token, platform: platform);
  }

  @override
  Future<void> markPendingActiveVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    final key = '$_pendingKeyPrefix$userId';
    final updated = await (_db.update(_db.appMeta)..where((m) => m.key.equals(key)))
        .write(AppMetaCompanion(value: Value(vehicleId)));
    if (updated == 0) {
      await _db
          .into(_db.appMeta)
          .insert(AppMetaCompanion.insert(key: key, value: Value(vehicleId)));
    }
  }

  @override
  Future<void> flushPendingActiveVehicle(String userId) async {
    final key = '$_pendingKeyPrefix$userId';
    final row = await (_db.select(_db.appMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    final vehicleId = row?.value;
    if (vehicleId == null || vehicleId.isEmpty) return;
    try {
      await update(activeVehicleId: vehicleId);
      await (_db.delete(_db.appMeta)..where((m) => m.key.equals(key))).go();
    } on ApiError catch (error) {
      if (error.code != 'network') {
        await (_db.delete(_db.appMeta)..where((m) => m.key.equals(key))).go();
      }
    }
  }
}

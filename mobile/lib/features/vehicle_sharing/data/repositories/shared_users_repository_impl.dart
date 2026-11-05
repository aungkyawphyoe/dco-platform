import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/shared_users_overview.dart';
import '../../domain/repositories/shared_users_repository.dart';

/// Account-scoped snapshot: a partial refresh never replaces the last complete
/// overview. All UI reads come from Drift, including after a network refresh.
class SharedUsersRepositoryImpl implements SharedUsersRepository {
  SharedUsersRepositoryImpl(this.db, this.dio, this.userId);
  final AppDatabase db;
  final Dio dio;
  final String userId;
  String get _key => 'shared-users:$userId';

  @override
  Stream<SharedUsersOverview?> watch() =>
      (db.select(
        db.appMeta,
      )..where((row) => row.key.equals(_key))).watchSingleOrNull().map(
        (row) => row?.value == null
            ? null
            : SharedUsersOverview.fromJson(
                jsonDecode(row!.value!) as Map<String, dynamic>,
              ),
      );

  @override
  Future<void> refresh() async {
    // Include archived owned vehicles: the server includes their active shares
    // in the account quota. Never fetch management data for received vehicles.
    final response = await dio.get<Map<String, dynamic>>(
      '/vehicles',
      queryParameters: {'include_archived': true},
    );
    final owned = (response.data!['items'] as List)
        .cast<Map<String, dynamic>>();
    final vehicles = <Map<String, dynamic>>[];
    for (final vehicle in owned) {
      final response = await dio.get<Map<String, dynamic>>(
        '/vehicles/${vehicle['id']}/shares',
      );
      vehicles.add(response.data!);
    }
    final entitlements = await dio.get<Map<String, dynamic>>(
      '/me/entitlements',
    );
    final snapshot = {
      'vehicles': vehicles,
      'sharing': entitlements.data!['vehicle_sharing'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    // Validate before replacing a usable cached snapshot.
    SharedUsersOverview.fromJson(snapshot);
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(
            key: _key,
            value: Value(jsonEncode(snapshot)),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}

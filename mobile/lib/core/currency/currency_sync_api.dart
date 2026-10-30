import 'package:dio/dio.dart';
import '../database/app_database.dart';
import '../network/auth_interceptor.dart';
import '../sync/sync_api.dart';
import 'currency_store.dart';

/// Network results populate the account-scoped local cache; widgets never read
/// these responses directly. Payload currency remains the original intent.
class CurrencySyncApi implements SyncApi {
  CurrencySyncApi(
    this.delegate,
    this.dio,
    this.db,
    this.userId, {
    this.organizationId,
  });
  final SyncApi delegate;
  final Dio dio;
  final AppDatabase db;
  final String userId;
  final String? organizationId;

  @override
  Future<List<SyncPushResult>> push(List<SyncOperationDto> operations) =>
      delegate.push(operations);

  @override
  Future<SyncPullPage> pull(String cursor) async {
    final page = await delegate.pull(cursor);
    try {
      final store = CurrencyStore(db);
      final response = await dio.get<Map<String, dynamic>>(
        organizationId == null
            ? '/me/currency'
            : '/organizations/$organizationId/currency',
      );
      final scope = {
        ...response.data!,
        if (organizationId != null) 'organization_id': organizationId,
      };
      await store.save(userId, scope);
      final vehicles = await db.select(db.vehicleRecords).get();
      final ids = {
        ...vehicles.map((v) => v.id),
        ...page.changes
            .where(
              (c) => c.entityType == 'vehicle' && c.op == SyncChangeOp.upsert,
            )
            .map((c) => c.entityId),
      };
      for (final id in ids) {
        if (organizationId != null) {
          await store.save(userId, scope, vehicleId: id);
        } else {
          try {
            final state = await dio.get<Map<String, dynamic>>(
              '/vehicles/$id/currency',
            );
            await store.save(userId, state.data!, vehicleId: id);
          } on DioException catch (error) {
            if (error.response?.statusCode != 403 &&
                error.response?.statusCode != 404) {
              rethrow;
            }
          }
        }
      }
    } on DioException catch (error) {
      throw mapDioError(error);
    }
    return page;
  }
}

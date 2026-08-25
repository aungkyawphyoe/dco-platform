// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required AppDatabase db,
    required OutboxWriter outbox,
  }) : _db = db,
       _outbox = outbox;

  final AppDatabase _db;
  final OutboxWriter _outbox;

  @override
  Stream<List<NotificationItem>> watch(String userId) {
    final query = _db.select(_db.notificationRecords)
      ..where((row) => row.userId.equals(userId))
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map((rows) => rows.map(_fromDrift).toList());
  }

  @override
  Future<void> setStatus({
    required String userId,
    required String notificationId,
    required NotificationStatus status,
  }) async {
    final now = DateTime.now().toUtc();
    final updated = await (_db.update(_db.notificationRecords)
          ..where((row) => row.id.equals(notificationId)))
        .write(
      NotificationRecordsCompanion(
        status: Value(status.storage),
        updatedAt: Value(now),
      ),
    );
    if (updated == 0) return;
    await _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.notification,
      entityId: notificationId,
      op: OutboxOp.upsert,
      payload: {'id': notificationId, 'status': status.storage},
    );
  }

  NotificationItem _fromDrift(NotificationRecord row) {
    return NotificationItem(
      id: row.id,
      userId: row.userId,
      vehicleId: row.vehicleId,
      planItemId: row.planItemId,
      title: row.title,
      body: row.body,
      status: NotificationStatus.parse(row.status),
      dueReason: NotificationDueReason.tryParse(row.dueReason),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

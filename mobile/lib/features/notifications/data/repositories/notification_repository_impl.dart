// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required AppDatabase db,
    required OutboxWriter outbox,
    Uuid uuid = const Uuid(),
  }) : _db = db,
       _outbox = outbox,
       _uuid = uuid;

  final AppDatabase _db;
  final OutboxWriter _outbox;
  final Uuid _uuid;

  @override
  Stream<List<NotificationItem>> watch(String userId) {
    final query = _db.select(_db.notificationRecords)
      ..where((row) => row.userId.equals(userId))
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map((rows) => rows.map(_fromDrift).toList());
  }

  @override
  Future<Set<String>> deliveredCycleKeys(String userId) async {
    final rows = await (_db.select(_db.notificationRecords)
          ..where((row) => row.userId.equals(userId) & row.cycleKey.isNotNull()))
        .get();
    return {
      for (final row in rows)
        if (row.planItemId != null && row.cycleKey != null)
          '${row.planItemId}::${row.cycleKey}',
    };
  }

  @override
  Future<NotificationItem> recordDue({
    required String userId,
    required String vehicleId,
    required String planItemId,
    required String cycleKey,
    required String title,
    required String body,
    NotificationDueReason? dueReason,
  }) async {
    final existing = await (_db.select(_db.notificationRecords)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                row.planItemId.equals(planItemId) &
                row.cycleKey.equals(cycleKey),
          ))
        .getSingleOrNull();
    if (existing != null) return _fromDrift(existing);

    final now = DateTime.now().toUtc();
    final item = NotificationItem(
      id: _uuid.v4(),
      userId: userId,
      vehicleId: vehicleId,
      planItemId: planItemId,
      title: title,
      body: body,
      status: NotificationStatus.unread,
      dueReason: dueReason,
      cycleKey: cycleKey,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.notificationRecords).insert(
      NotificationRecordsCompanion.insert(
        id: item.id,
        userId: item.userId,
        vehicleId: Value(item.vehicleId),
        planItemId: Value(item.planItemId),
        title: item.title,
        body: item.body,
        status: Value(item.status.storage),
        dueReason: Value(item.dueReason?.storage),
        cycleKey: Value(item.cycleKey),
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ),
    );
    return item;
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
      cycleKey: row.cycleKey,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

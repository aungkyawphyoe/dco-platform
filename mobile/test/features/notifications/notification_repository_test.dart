// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:dco_mobile/features/notifications/domain/entities/notification.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NotificationRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotificationRepositoryImpl(db: db, outbox: OutboxWriter(db));
  });

  tearDown(() => db.close());

  Future<void> seed() {
    return db.into(db.notificationRecords).insert(
      NotificationRecordsCompanion.insert(
        id: 'n1',
        userId: 'u1',
        title: 'Oil change due',
        body: 'Due in 200 mi',
        dueReason: const Value('both'),
        createdAt: DateTime.parse('2026-02-01T08:00:00.000Z'),
        updatedAt: DateTime.parse('2026-02-01T08:00:00.000Z'),
      ),
    );
  }

  test('watch emits parsed items newest first', () async {
    await seed();
    await db.into(db.notificationRecords).insert(
      NotificationRecordsCompanion.insert(
        id: 'n2',
        userId: 'u1',
        title: 'Tires rotated',
        body: 'Due soon',
        createdAt: DateTime.parse('2026-02-03T08:00:00.000Z'),
        updatedAt: DateTime.parse('2026-02-03T08:00:00.000Z'),
      ),
    );

    final items = await repo.watch('u1').first;

    expect(items.map((item) => item.id), ['n2', 'n1']);
    expect(items.last.status, NotificationStatus.unread);
    expect(items.last.dueReason, NotificationDueReason.both);
  });

  test('watch is scoped to the user', () async {
    await seed();
    final items = await repo.watch('u2').first;
    expect(items, isEmpty);
  });

  test('setStatus updates the row and queues an outbox op', () async {
    await seed();

    await repo.setStatus(
      userId: 'u1',
      notificationId: 'n1',
      status: NotificationStatus.done,
    );

    final row = await (db.select(db.notificationRecords)
          ..where((r) => r.id.equals('n1')))
        .getSingle();
    expect(row.status, 'done');

    final outboxRows = await db.select(db.outboxEntries).get();
    expect(outboxRows.single.entityType, 'notification');
    expect(outboxRows.single.payload, '{"id":"n1","status":"done"}');
  });

  test('setStatus on a missing row is a no-op', () async {
    await repo.setStatus(
      userId: 'u1',
      notificationId: 'missing',
      status: NotificationStatus.read,
    );
    final outboxRows = await db.select(db.outboxEntries).get();
    expect(outboxRows, isEmpty);
  });

  test('recordDue inserts once per plan item cycle', () async {
    final first = await repo.recordDue(
      userId: 'u1',
      vehicleId: 'v1',
      planItemId: 'p1',
      cycleKey: '2026-09-01|',
      title: 'Maintenance Reminder',
      body: 'Oil Change',
      dueReason: NotificationDueReason.date,
    );
    final second = await repo.recordDue(
      userId: 'u1',
      vehicleId: 'v1',
      planItemId: 'p1',
      cycleKey: '2026-09-01|',
      title: 'Maintenance Reminder',
      body: 'Oil Change',
      dueReason: NotificationDueReason.date,
    );
    expect(second.id, first.id);
    expect(await repo.deliveredCycleKeys('u1'), {'p1::2026-09-01|'});
    final outboxRows = await db.select(db.outboxEntries).get();
    expect(outboxRows, isEmpty);
  });
}

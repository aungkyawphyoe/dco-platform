import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/network/api_error.dart';
import 'package:dco_mobile/core/sync/outbox_models.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'sync_engine_test.dart' show FakeMediaApi, FakeSyncApi;

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late OutboxWriter outbox;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    outbox = OutboxWriter(db);
    engine = SyncEngine(
      db: db,
      api: api,
      mediaApi: FakeMediaApi(),
      currentUser: () => 'u1',
      autoSyncEnabled: () => true,
      outbox: outbox,
      uuid: const Uuid(),
      debounce: Duration.zero,
    );
  });

  tearDown(() {
    engine.dispose();
    db.close();
  });

  Future<void> enqueue(String userId, String type, String id) {
    return outbox.enqueue(
      userId: userId,
      entityType: type,
      entityId: id,
      op: OutboxOp.upsert,
      payload: {'id': id},
    );
  }

  const limitError = ApiError(
    code: 'LIMIT_EXCEEDED',
    message: 'Free plan allows 1 vehicle. Upgrade to Lite for 3 vehicles.',
    details: {'metric': 'vehicles', 'current': 1, 'limit': 1},
  );

  test(
      'LIMIT_EXCEEDED parks the row without burning a retry and keeps siblings syncing',
      () async {
    await enqueue('u1', OutboxEntityType.vehicle, 'v1');
    await enqueue('u1', OutboxEntityType.expense, 'e1');
    api.pushHandler = (ops) => ops
        .map(
          (op) => op.entityId == 'v1'
              ? const SyncPushResult(
                  entityId: 'v1',
                  status: SyncPushStatus.rejected,
                  error: limitError,
                )
              : SyncPushResult(
                  entityId: op.entityId,
                  status: SyncPushStatus.applied,
                ),
        )
        .toList();

    await engine.syncNow();

    final rows = await db.select(db.outboxEntries).get();
    final parkedRow = rows.single;
    expect(parkedRow.entityId, 'v1');
    expect(parkedRow.parked, isTrue);
    expect(parkedRow.attemptCount, 0);
    expect(parkedRow.lastError, limitError.message);
    // The sibling synced fine in the same batch.
    expect(api.recordedOps.map((o) => o.entityId), contains('e1'));
  });

  test('parked rows are excluded from later pushes', () async {
    await enqueue('u1', OutboxEntityType.vehicle, 'v1');
    api.pushHandler = (ops) => ops
        .map(
          (op) => const SyncPushResult(
            entityId: 'v1',
            status: SyncPushStatus.rejected,
            error: limitError,
          ),
        )
        .toList();
    await engine.syncNow();

    api.recordedOps.clear();
    api.pushHandler = null;
    await engine.syncNow();

    expect(api.recordedOps, isEmpty);
    final row = await db.select(db.outboxEntries).getSingle();
    expect(row.parked, isTrue);
  });

  test('requeueParked re-enables rows and they drain on the next sync',
      () async {
    await enqueue('u1', OutboxEntityType.vehicle, 'v1');
    api.pushHandler = (ops) => ops
        .map(
          (op) => const SyncPushResult(
            entityId: 'v1',
            status: SyncPushStatus.rejected,
            error: limitError,
          ),
        )
        .toList();
    await engine.syncNow();

    // Fresh license arrived → upgrade lifted the cap.
    await engine.requeueParked('u1');
    api.pushHandler = null;
    await engine.syncNow();

    expect(await db.select(db.outboxEntries).get(), isEmpty);
  });

  test('requeueParked only touches the given user', () async {
    final now = DateTime.now().toUtc();
    OutboxEntriesCompanion insertRow(String userId, String entityId) =>
        OutboxEntriesCompanion.insert(
          userId: userId,
          entityType: OutboxEntityType.vehicle,
          entityId: entityId,
          op: 'upsert',
          payload: '{}',
          clientTs: now,
          parked: const Value(true),
        );
    await db.into(db.outboxEntries).insert(insertRow('u1', 'v1'));
    await db.into(db.outboxEntries).insert(insertRow('u2', 'v2'));

    await engine.requeueParked('u1');

    final rows = await db.select(db.outboxEntries).get();
    expect(rows.firstWhere((r) => r.userId == 'u1').parked, isFalse);
    expect(rows.firstWhere((r) => r.userId == 'u2').parked, isTrue);
  });

  test('ordinary rejections still increment the attempt counter', () async {
    await enqueue('u1', OutboxEntityType.expense, 'e1');
    api.pushHandler = (ops) => ops
        .map(
          (op) => const SyncPushResult(
            entityId: 'e1',
            status: SyncPushStatus.rejected,
            error: ApiError(code: 'validation', message: 'bad payload'),
          ),
        )
        .toList();

    await engine.syncNow();

    final row = await db.select(db.outboxEntries).getSingle();
    expect(row.parked, isFalse);
    expect(row.attemptCount, 1);
  });
}

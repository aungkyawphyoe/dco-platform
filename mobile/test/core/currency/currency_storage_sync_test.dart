import 'dart:convert';
import 'dart:io';
import 'package:dco_mobile/core/currency/currency_store.dart';
import 'package:dco_mobile/core/currency/currency_conflict_repository.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/network/api_error.dart';
import 'package:dco_mobile/core/sync/change_applier.dart';
import 'package:dco_mobile/core/sync/outbox_models.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:dco_mobile/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../sync/sync_engine_test.dart' show FakeSyncApi, FakeMediaApi;

Map<String, dynamic> state(String? currency) => {
  'currency': currency,
  'enabled': true,
  'locked': false,
  'review_required': false,
};
Map<String, dynamic> expense(
  String id, {
  String currency = 'MMK',
  double amount = 12.5,
}) => {
  'id': id,
  'vehicle_id': 'v1',
  'category': 'parking',
  'amount': amount,
  'currency': currency,
  'incurred_on': '2026-01-01',
  'parts': <Map<String, dynamic>>[],
};
SyncChange change(String id, Map<String, dynamic> payload) => SyncChange(
  entityType: 'expense',
  entityId: id,
  op: SyncChangeOp.upsert,
  payload: payload,
  serverTs: DateTime.utc(2026, 10, 30),
);

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  test(
    'v24 migration preserves fractional legacy values and stamps queued intent as MMK',
    () async {
      final dir = await Directory.systemTemp.createTemp('currency-migration');
      final file = File('${dir.path}/old.sqlite');
      var disk = AppDatabase(NativeDatabase(file));
      await ChangeApplier(
        disk,
      ).apply(change('legacy', expense('legacy')), userId: 'u1');
      await OutboxWriter(disk).enqueue(
        userId: 'u1',
        entityType: 'expense',
        entityId: 'legacy',
        op: OutboxOp.upsert,
        payload: {...expense('legacy')}..remove('currency'),
      );
      for (final entry in {
        'vehicles': 'purchase_currency',
        'service_records': 'currency',
        'fuel_logs': 'currency',
        'expenses': 'currency',
      }.entries) {
        await disk.customStatement(
          'ALTER TABLE ${entry.key} DROP COLUMN ${entry.value}',
        );
      }
      await disk.customStatement(
        'ALTER TABLE outbox_entries DROP COLUMN error_code',
      );
      await disk.customStatement(
        'ALTER TABLE outbox_entries DROP COLUMN error_details',
      );
      await disk.customStatement('PRAGMA user_version = 24');
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      try {
        final saved = await disk.select(disk.expenseRecords).getSingle();
        expect(saved.amount, 12.5);
        expect(saved.currency, 'MMK');
        final queued = await disk.select(disk.outboxEntries).getSingle();
        expect(jsonDecode(queued.payload)['currency'], 'MMK');
        expect(jsonDecode(queued.payload)['amount'], 12.5);
        expect(disk.schemaVersion, 25);
      } finally {
        await disk.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'scope cache isolates users and shared vehicle currency; local writes lock atomically',
    () async {
      final store = CurrencyStore(db);
      await store.save('u1', state('USD'));
      await store.save('u1', state('THB'), vehicleId: 'v1');
      expect(await store.read('u2'), isNull);
      expect(await store.validateCreation('u1', 'THB', vehicleId: 'v1'), 'THB');
      await expectLater(
        store.validateCreation('u1', 'USD', vehicleId: 'v1'),
        throwsStateError,
      );
      await expectLater(
        store.validateCreation('u1', 'MMK', vehicleId: 'uncached'),
        throwsStateError,
      );
      final repo = ExpenseRepositoryImpl(db: db, outbox: OutboxWriter(db));
      final saved = await repo.add(
        userId: 'u1',
        vehicleId: 'v1',
        draft: ExpenseDraft(
          currency: 'THB',
          category: ExpenseCategory.parking,
          amount: 12.25,
          incurredOn: DateTime(2026, 1, 1),
        ),
      );
      expect(saved.currency, 'THB');
      expect((await db.select(db.expenseRecords).getSingle()).currency, 'THB');
      expect(
        jsonDecode(
          (await db.select(db.outboxEntries).getSingle()).payload,
        )['currency'],
        'THB',
      );
      expect(await store.hasLocalLock('u1', vehicleId: 'v1'), isTrue);
      // Owner currency may change after transfer; historical edits retain THB.
      await store.save('u1', state('CNY'), vehicleId: 'v1');
      final updated = await repo.update(
        userId: 'u1',
        expenseId: saved.id,
        draft: ExpenseDraft(
          category: ExpenseCategory.parking,
          amount: 12.25,
          incurredOn: DateTime(2026, 1, 1),
          notes: 'Corrected note',
        ),
      );
      expect(updated.currency, 'THB');
    },
  );

  test(
    'currency rejection preserves draft, does not burn retries, and lets later records sync',
    () async {
      await ChangeApplier(db).apply(change('e1', expense('e1')), userId: 'u1');
      final outbox = OutboxWriter(db);
      for (final id in ['e1', 'e2']) {
        await outbox.enqueue(
          userId: 'u1',
          entityType: 'expense',
          entityId: id,
          op: OutboxOp.upsert,
          payload: expense(id),
        );
      }
      final api = FakeSyncApi()
        ..pushHandler = (ops) => ops
            .map(
              (op) => SyncPushResult(
                entityId: op.entityId,
                status: op.entityId == 'e1'
                    ? SyncPushStatus.rejected
                    : SyncPushStatus.applied,
                error: op.entityId == 'e1'
                    ? const ApiError(
                        code: 'currency_mismatch',
                        message: 'Re-enter in USD',
                        details: {'current_currency': 'USD'},
                      )
                    : null,
              ),
            )
            .toList();
      final engine = SyncEngine(
        db: db,
        api: api,
        mediaApi: FakeMediaApi(),
        currentUser: () => 'u1',
        autoSyncEnabled: () => true,
        batchSize: 1,
      );
      try {
        await engine.syncNow();
        final row = await db.select(db.outboxEntries).getSingle();
        expect(row.entityId, 'e1');
        expect(row.parked, isTrue);
        expect(row.attemptCount, 0);
        expect(jsonDecode(row.errorDetails!)['current_currency'], 'USD');
        expect(api.recordedOps.map((r) => r.entityId), contains('e2'));
        await engine.requeueParked('u1');
        await engine.syncNow(force: true);
        expect((await db.select(db.outboxEntries).getSingle()).parked, isTrue);
        await ChangeApplier(db, authoritative: true).apply(
          change('e1', expense('e1', currency: 'USD', amount: 99)),
          userId: 'u1',
        );
        expect((await db.select(db.expenseRecords).getSingle()).amount, 12.5);
        await expectLater(
          outbox.enqueue(
            userId: 'u1',
            entityType: 'expense',
            entityId: 'e1',
            op: OutboxOp.upsert,
            payload: expense('e1'),
          ),
          throwsStateError,
        );
        final recovery = CurrencyConflictRepository(
          db,
          'u1',
          (_) async => state('USD'),
        );
        await expectLater(
          recovery.resolve(outboxId: row.id, currency: 'THB', amount: 10),
          throwsStateError,
        );
        await recovery.resolve(
          outboxId: row.id,
          currency: 'USD',
          amount: 10.25,
        );
        final fixed = await db.select(db.outboxEntries).getSingle();
        expect(fixed.parked, isFalse);
        expect(fixed.entityId, 'e1');
        expect(jsonDecode(fixed.payload)['amount'], 10.25);
        expect(
          (await db.select(db.expenseRecords).getSingle()).currency,
          'USD',
        );
      } finally {
        engine.dispose();
      }
    },
  );

  test('another account cannot resolve a preserved draft', () async {
    await db
        .into(db.outboxEntries)
        .insert(
          OutboxEntriesCompanion.insert(
            userId: 'u1',
            entityType: 'expense',
            entityId: 'e1',
            op: 'upsert',
            payload: jsonEncode(expense('e1')),
            clientTs: DateTime.now(),
            parked: const Value(true),
            errorCode: const Value('currency_mismatch'),
          ),
        );
    final row = await db.select(db.outboxEntries).getSingle();
    await expectLater(
      CurrencyConflictRepository(
        db,
        'u2',
        (_) async => state('USD'),
      ).resolve(outboxId: row.id, currency: 'USD', amount: 1),
      throwsStateError,
    );
    expect(
      (await db.select(db.outboxEntries).getSingle()).payload,
      row.payload,
    );
  });
  test(
    'linked expense waits behind its rejected service and recovers atomically',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      final source = {
        'id': 's1',
        'vehicle_id': 'v1',
        'currency': 'MMK',
        'total_cost': 100.0,
        'serviced_on': '2026-01-01',
        'odometer': 10.0,
        'items': [
          {'id': 'line1', 'name': 'Oil', 'line_cost': 100.0},
        ],
        'parts': [],
      };
      await ChangeApplier(db).apply(
        SyncChange(
          entityType: 'service_record',
          entityId: 's1',
          op: SyncChangeOp.upsert,
          payload: source,
          serverTs: now,
        ),
        userId: 'u1',
      );
      await ChangeApplier(
        db,
      ).apply(change('e1', expense('e1', amount: 100)), userId: 'u1');
      final outbox = OutboxWriter(db);
      await outbox.enqueue(
        userId: 'u1',
        entityType: 'service_record',
        entityId: 's1',
        op: OutboxOp.upsert,
        payload: source,
      );
      await outbox.enqueue(
        userId: 'u1',
        entityType: 'expense',
        entityId: 'e1',
        op: OutboxOp.upsert,
        payload: {...expense('e1', amount: 100), '_currency_parent_id': 's1'},
      );
      final api = FakeSyncApi()
        ..pushHandler = (ops) => ops
            .map(
              (op) => SyncPushResult(
                entityId: op.entityId,
                status: SyncPushStatus.rejected,
                error: const ApiError(
                  code: 'currency_mismatch',
                  message: 'Currency changed',
                ),
              ),
            )
            .toList();
      final engine = SyncEngine(
        db: db,
        api: api,
        mediaApi: FakeMediaApi(),
        currentUser: () => 'u1',
        autoSyncEnabled: () => true,
      );
      try {
        await engine.syncNow();
        expect(api.recordedOps.map((r) => r.entityId).toList(), ['s1']);
        await ChangeApplier(db, authoritative: true).apply(
          change('e1', expense('e1', currency: 'USD', amount: 999)),
          userId: 'u1',
        );
        expect((await db.select(db.expenseRecords).getSingle()).amount, 100);
        final row = await (db.select(
          db.outboxEntries,
        )..where((r) => r.entityId.equals('s1'))).getSingle();
        final recovery = CurrencyConflictRepository(
          db,
          'u1',
          (_) async => state('USD'),
        );
        await expectLater(
          recovery.resolve(outboxId: row.id, currency: 'USD', amount: 3.5),
          throwsStateError,
        );
        expect(
          (await db.select(db.serviceRecordRows).getSingle()).currency,
          'MMK',
        );
        await recovery.resolve(
          outboxId: row.id,
          currency: 'USD',
          amount: 3.5,
          lineCosts: [3.5],
        );
        expect(
          (await db.select(db.serviceRecordRows).getSingle()).totalCost,
          3.5,
        );
        expect(
          (await db.select(db.serviceLineRecords).getSingle()).lineCost,
          3.5,
        );
        expect(
          (await db.select(db.expenseRecords).getSingle()).currency,
          'USD',
        );
        final linked = await (db.select(
          db.outboxEntries,
        )..where((r) => r.entityId.equals('e1'))).getSingle();
        expect(jsonDecode(linked.payload)['amount'], 3.5);
      } finally {
        engine.dispose();
      }
    },
  );
  test(
    'multiple offline edits require review of the newest draft before superseding',
    () async {
      final first = expense('e1')..['_expected_revision'] = null;
      await db
          .into(db.outboxEntries)
          .insert(
            OutboxEntriesCompanion.insert(
              userId: 'u1',
              entityType: 'expense',
              entityId: 'e1',
              op: 'upsert',
              payload: jsonEncode(first),
              clientTs: DateTime.now(),
              parked: const Value(true),
              errorCode: const Value('currency_mismatch'),
            ),
          );
      await db
          .into(db.outboxEntries)
          .insert(
            OutboxEntriesCompanion.insert(
              userId: 'u1',
              entityType: 'expense',
              entityId: 'e1',
              op: 'upsert',
              payload: jsonEncode({
                ...first,
                'notes': 'Latest offline edit',
                '_expected_revision': 1,
              }),
              clientTs: DateTime.now(),
            ),
          );
      final rows = await db.select(db.outboxEntries).get();
      final recovery = CurrencyConflictRepository(
        db,
        'u1',
        (_) async => state('THB'),
      );
      await expectLater(
        recovery.resolve(outboxId: rows.first.id, currency: 'THB', amount: 50),
        throwsStateError,
      );
      expect((await db.select(db.outboxEntries).get()).length, 2);
      await recovery.resolve(
        outboxId: rows.first.id,
        currency: 'THB',
        amount: 50,
        reviewedThroughId: rows.last.id,
      );
      final fixed = await db.select(db.outboxEntries).getSingle();
      expect(fixed.entityId, 'e1');
      expect(jsonDecode(fixed.payload)['notes'], 'Latest offline edit');
      expect(jsonDecode(fixed.payload)['_expected_revision'], isNull);
    },
  );
}

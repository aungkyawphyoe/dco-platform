import 'dart:io';
import 'dart:convert';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/notifications/local_notification_client.dart';
import 'package:dco_mobile/core/storage/account_lifecycle.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dco_mobile/core/sync/outbox_models.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MemoryTokenStore tokens;
  late NoopLocalNotificationClient notifications;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tokens = MemoryTokenStore();
    notifications = NoopLocalNotificationClient();
  });
  tearDown(() => db.close());

  test(
    'fresh installation removes surviving credentials before restore',
    () async {
      await tokens.writeSession(
        accessToken: 'old',
        refreshToken: 'old-refresh',
        userJson: jsonEncode({'id': 'old-user'}),
      );
      var secretsCleared = false;
      final lifecycle = AccountLifecycle(
        primary: db,
        tokens: tokens,
        notifications: notifications,
        journal: MemoryLifecycleJournal(),
        clearSecrets: () async {
          secretsCleared = true;
        },
      );
      await lifecycle.initialize();
      expect(await tokens.readRefreshToken(), isNull);
      expect(secretsCleared, isTrue);
    },
  );

  test(
    'cleanup clears all account rows, preferences, scoped databases and notifications',
    () async {
      final org = AppDatabase(NativeDatabase.memory());
      addTearDown(org.close);
      final journal = MemoryLifecycleJournal()..value = {'installed': true};
      var filesCleared = false;
      final lifecycle = AccountLifecycle(
        primary: db,
        tokens: tokens,
        notifications: notifications,
        journal: journal,
        clearSecrets: () async {},
        cleanFiles: () async {
          filesCleared = true;
        },
      );
      lifecycle.register(org);
      for (final database in [db, org]) {
        await database
            .into(database.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                userId: 'user-1',
                themeMode: const Value('dark'),
              ),
            );
        await database
            .into(database.noteRecords)
            .insert(
              NoteRecordsCompanion.insert(
                id: 'note',
                userId: 'user-1',
                body: const Value('private'),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            );
        await database
            .into(database.appMeta)
            .insert(
              AppMetaCompanion.insert(
                key: 'entry.language',
                value: const Value('my'),
              ),
            );
      }
      notifications.shown.add(1);
      notifications.scheduled.add(2);
      await lifecycle.initialize();
      await lifecycle.lock('user-1');
      await lifecycle.purge();
      for (final database in [db, org]) {
        for (final table in database.allTables) {
          expect(
            await database
                .customSelect('SELECT * FROM "${table.actualTableName}"')
                .get(),
            isEmpty,
            reason: table.actualTableName,
          );
        }
      }
      expect(filesCleared, isTrue);
      expect(notifications.shown, isEmpty);
      expect(notifications.scheduled, isEmpty);
      expect(journal.value!['cleanup_pending'], false);
      expect(lifecycle.lockedUserId, isNull);
    },
  );

  test(
    'interrupted cleanup is durable and retried on the next launch',
    () async {
      final journal = MemoryLifecycleJournal()
        ..value = {'installed': true, 'locked_user_id': 'user-1'};
      var fail = true;
      Future<void> files() async {
        if (fail) throw StateError('file busy');
      }

      AccountLifecycle create() => AccountLifecycle(
        primary: db,
        tokens: tokens,
        notifications: notifications,
        journal: journal,
        clearSecrets: () async {},
        cleanFiles: files,
      );
      final first = create();
      await first.initialize();
      await expectLater(first.purge(), throwsStateError);
      expect(journal.value!['cleanup_pending'], true);
      expect(journal.value!['locked_user_id'], 'user-1');
      fail = false;
      final restarted = create();
      await restarted.initialize();
      expect(restarted.cleanupPending, false);
      expect(restarted.lockedUserId, isNull);
    },
  );

  test(
    'rejected and parked changes remain visible until explicitly discarded',
    () async {
      final lifecycle = AccountLifecycle(
        primary: db,
        tokens: tokens,
        notifications: notifications,
        journal: MemoryLifecycleJournal()..value = {'installed': true},
        clearSecrets: () async {},
      );
      await OutboxWriter(db).enqueue(
        userId: 'user-1',
        entityType: 'expense',
        entityId: 'expense',
        op: OutboxOp.upsert,
        payload: {'id': 'expense'},
      );
      await db
          .update(db.outboxEntries)
          .write(
            const OutboxEntriesCompanion(
              parked: Value(true),
              errorCode: Value('invalid_request'),
            ),
          );
      final pending = await lifecycle.pending();
      expect(pending.items, ['expense']);
      expect(pending.canDiscard, true);
      expect(await db.select(db.outboxEntries).get(), hasLength(1));
    },
  );
  test(
    'managed caches are removed while exported files remain outside app storage',
    () async {
      final root = await Directory.systemTemp.createTemp('account-files');
      try {
        final documents = await Directory('${root.path}/documents').create();
        final support = await Directory('${root.path}/support').create();
        final temporary = await Directory('${root.path}/cache').create();
        for (final path in [
          '${documents.path}/vehicles/photo.jpg',
          '${documents.path}/expenses/receipt.jpg',
          '${support.path}/documents/private.pdf',
          '${temporary.path}/upload.tmp',
        ]) {
          await File(path).parent.create(recursive: true);
          await File(path).writeAsString('private');
        }
        final exported = await File(
          '${root.path}/exported.pdf',
        ).writeAsString('export');
        await cleanAccountFiles(
          documentsDirectory: documents,
          supportDirectory: support,
          temporaryDirectory: temporary,
        );
        expect(await Directory('${documents.path}/vehicles').exists(), false);
        expect(await Directory('${support.path}/documents').exists(), false);
        expect(await temporary.list().toList(), isEmpty);
        expect(await exported.exists(), true);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'pending work in inactive fleet databases is checked before cleanup',
    () async {
      final root = await Directory.systemTemp.createTemp('inactive-fleet');
      try {
        final file = File('${root.path}/fleet.sqlite');
        final old = AppDatabase(NativeDatabase(file));
        await OutboxWriter(old).enqueue(
          userId: 'user-1',
          entityType: 'expense',
          entityId: 'old',
          op: OutboxOp.upsert,
          payload: {'id': 'old'},
        );
        await old.close();
        final lifecycle = AccountLifecycle(
          primary: db,
          tokens: tokens,
          notifications: notifications,
          journal: MemoryLifecycleJournal()..value = {'installed': true},
          clearSecrets: () async {},
          discoverDatabases: () async => [AppDatabase(NativeDatabase(file))],
        );
        final pending = await lifecycle.pending();
        expect(pending.items, ['expense']);
        expect(pending.canDiscard, true);
        await lifecycle.purge();
        final cleared = AppDatabase(NativeDatabase(file));
        expect(await cleared.select(cleared.outboxEntries).get(), isEmpty);
        await cleared.close();
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'a stale response cannot write tokens after logout clears the session',
    () async {
      final generation = tokens.generation;
      await tokens.clear();
      await expectLater(
        tokens.writeSession(
          accessToken: 'old',
          refreshToken: 'old',
          userJson: '{}',
          expectedGeneration: generation,
        ),
        throwsStateError,
      );
      expect(await tokens.readRefreshToken(), isNull);
    },
  );

  test(
    'concurrent journal writes leave a complete final cleanup state',
    () async {
      final root = await Directory.systemTemp.createTemp('account-journal');
      try {
        final journal = FileLifecycleJournal(File('${root.path}/journal.json'));
        await Future.wait([
          journal.write({
            'installed': true,
            'locked_user_id': 'user-1',
            'cleanup_pending': false,
          }),
          journal.write({
            'installed': true,
            'locked_user_id': 'user-1',
            'cleanup_pending': true,
          }),
          journal.write({
            'installed': true,
            'locked_user_id': null,
            'cleanup_pending': false,
          }),
        ]);
        expect(await journal.read(), {
          'installed': true,
          'locked_user_id': null,
          'cleanup_pending': false,
        });
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}

import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/gating/license_store.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/notifications/local_notification_client.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/storage/account_lifecycle.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dco_mobile/core/sync/outbox_models.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:dco_mobile/features/auth/domain/auth_failure.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../core/sync/sync_engine_test.dart' show FakeSyncApi, FakeMediaApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  late MemoryTokenStore tokens;
  late AccountLifecycle lifecycle;
  late FakeSyncApi api;
  var failCleanup = false;
  setUp(() async {
    failCleanup = false;
    db = AppDatabase(NativeDatabase.memory());
    tokens = MemoryTokenStore();
    final notifications = NoopLocalNotificationClient();
    final licenses = MemoryLicenseStore();
    lifecycle = AccountLifecycle(
      primary: db,
      tokens: tokens,
      notifications: notifications,
      journal: MemoryLifecycleJournal()..value = {'installed': true},
      clearSecrets: licenses.clearAll,
      cleanFiles: () async {
        if (failCleanup) throw StateError('file busy');
      },
    );
    api = FakeSyncApi();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        accountLifecycleProvider.overrideWithValue(lifecycle),
        tokenStoreProvider.overrideWithValue(tokens),
        licenseStoreProvider.overrideWithValue(licenses),
        localNotificationClientProvider.overrideWithValue(notifications),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://localhost:8080/v1',
            jwtOwnerAud: 'dco-owner',
            mockAuth: true,
            analyticsEnabled: false,
          ),
        ),
        syncApiProvider.overrideWithValue(api),
        mediaApiProvider.overrideWithValue(FakeMediaApi()),
      ],
    );
    await container.read(sessionControllerProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> login(String email) async {
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(email: email, password: 'password1');
    final id = container.read(sessionControllerProvider).requireValue!.user.id;
    container.read(syncEngineProvider);
    await container.read(syncAccountCoordinatorProvider).pause();
    return id;
  }

  Future<void> queue(String user) => OutboxWriter(db).enqueue(
    userId: user,
    entityType: 'expense',
    entityId: 'queued',
    op: OutboxOp.upsert,
    payload: {'id': 'queued', 'vehicle_id': 'vehicle'},
  );

  test('fresh signup confirms an empty garage before its first sync', () async {
    await container.read(sessionControllerProvider.future);
    await container
        .read(sessionControllerProvider.notifier)
        .signUp(email: 'fresh@example.com', password: 'password12');
    final id = container.read(sessionControllerProvider).valueOrNull!.user.id;
    final marker = await (db.select(
      db.appMeta,
    )..where((row) => row.key.equals('garage_loaded:$id'))).getSingle();
    expect(marker.value, 'true');
    expect(await db.select(db.vehicleRecords).get(), isEmpty);
  });

  test(
    'logout drains changes, removes all preferences and prevents the next account seeing notes',
    () async {
      final first = await login('first@test.local');
      final oldUser = container
          .read(sessionControllerProvider)
          .requireValue!
          .user;
      await db
          .into(db.noteRecords)
          .insert(
            NoteRecordsCompanion.insert(
              id: 'private-note',
              userId: first,
              title: const Value('Private'),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );
      await db
          .update(db.userProfiles)
          .write(
            const UserProfilesCompanion(
              themeMode: Value('dark'),
              language: Value('my'),
            ),
          );
      await queue(first);
      await container.read(sessionControllerProvider.notifier).signOut();
      expect(api.recordedOps.map((row) => row.entityId), contains('queued'));
      expect(await tokens.readRefreshToken(), isNull);
      expect(await db.select(db.noteRecords).get(), isEmpty);
      expect(await db.select(db.userProfiles).get(), isEmpty);
      final second = await login('second@test.local');
      expect(second, isNot(first));
      container.read(sessionControllerProvider.notifier).updateUser(oldUser);
      expect(
        container.read(sessionControllerProvider).requireValue!.user.id,
        second,
      );
      expect(await db.select(db.noteRecords).get(), isEmpty);
      expect(
        (await db.select(db.userProfiles).getSingle()).themeMode,
        'system',
      );
    },
  );

  test(
    'failed sync retains the session and data until explicit discard',
    () async {
      final user = await login('first@test.local');
      await queue(user);
      api.pushHandler = (ops) => ops
          .map(
            (row) => SyncPushResult(
              entityId: row.entityId,
              status: SyncPushStatus.rejected,
            ),
          )
          .toList();
      await expectLater(
        container.read(sessionControllerProvider.notifier).signOut(),
        throwsA(isA<LogoutSyncFailure>()),
      );
      expect(
        container.read(sessionControllerProvider).requireValue!.user.id,
        user,
      );
      expect(await db.select(db.outboxEntries).get(), isNotEmpty);
      await container
          .read(sessionControllerProvider.notifier)
          .signOut(discardUnsynced: true);
      expect(await db.select(db.outboxEntries).get(), isEmpty);
      expect(container.read(sessionControllerProvider).requireValue, isNull);
    },
  );

  test(
    'expired session permits only its original account to reauthenticate',
    () async {
      final first = await login('first@test.local');
      await queue(first);
      await tokens.clear();
      await container.read(sessionControllerProvider.notifier).sessionExpired();
      await expectLater(
        login('second@test.local'),
        throwsA(isA<ApiAuthFailure>()),
      );
      expect(lifecycle.lockedUserId, first);
      expect(await db.select(db.outboxEntries).get(), isNotEmpty);
      expect(await login('first@test.local'), first);
    },
  );
  test(
    'failed cleanup hides the account and blocks another login until cleanup completes',
    () async {
      await login('first@test.local');
      failCleanup = true;
      await expectLater(
        container.read(sessionControllerProvider.notifier).signOut(),
        throwsStateError,
      );
      expect(container.read(sessionControllerProvider).requireValue, isNull);
      expect(lifecycle.cleanupPending, true);
      await expectLater(
        login('second@test.local'),
        throwsA(isA<ApiAuthFailure>()),
      );
      failCleanup = false;
      await container
          .read(sessionControllerProvider.notifier)
          .signOut(discardUnsynced: true);
      await login('second@test.local');
      expect(lifecycle.cleanupPending, false);
    },
  );
}

import 'currency/currency_conflict_repository.dart';
import 'currency/currency_sync_api.dart';
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gating/providers.dart';
import 'gating/trusted_clock.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/dio_auth_remote_datasource.dart';
import '../../features/auth/data/datasources/mock_auth_remote_datasource.dart';
import '../../features/auth/data/datasources/profile_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/profile_repository_impl.dart';
import '../../features/auth/domain/entities/session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/profile_repository.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/documents/data/repositories/document_repository_impl.dart';
import '../../features/documents/domain/repositories/document_repository.dart';
import '../../features/expenses/data/repositories/expense_repository_impl.dart';
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/fuel/data/repositories/fuel_repository_impl.dart';
import '../../features/fuel/domain/repositories/fuel_repository.dart';
import '../../features/garage/data/repositories/vehicle_repository_impl.dart';
import '../../features/garage/domain/repositories/vehicle_repository.dart';
import '../../features/maintenance/data/repositories/maintenance_catalog_repository_impl.dart';
import '../../features/maintenance/data/repositories/maintenance_repository_impl.dart';
import '../../features/maintenance/domain/repositories/maintenance_catalog_repository.dart';
import '../../features/maintenance/domain/repositories/maintenance_repository.dart';
import '../../features/notifications/data/reminder_schedule_store.dart';
import '../../features/notifications/data/reminder_sync_service.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notes/data/repositories/notes_repository_impl.dart';
import '../../features/notes/domain/repositories/notes_repository.dart';
import '../../features/parts/data/repositories/parts_repository_impl.dart';
import '../../features/parts/domain/repositories/parts_repository.dart';
import '../../features/settings/data/repositories/license_repository_impl.dart';
import '../../features/settings/data/repositories/preferences_repository_impl.dart';
import '../../features/settings/domain/repositories/license_repository.dart';
import '../../features/settings/domain/repositories/preferences_repository.dart';
import 'analytics/analytics.dart';
import 'config/app_config.dart';
import 'database/app_database.dart';
import 'media/media_api.dart';
import 'media/document_cache.dart';
import 'network/dio_client.dart';
import 'notifications/flutter_local_notification_client.dart';
import 'notifications/local_notification_client.dart';
import 'storage/token_store.dart';
import 'sync/outbox_writer.dart';
import 'sync/sync_api.dart';
import 'sync/organization_sync_api.dart';
import 'sync/change_applier.dart';
import '../../features/fleet/providers.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_account_coordinator.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig must be overridden in bootstrap');
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  throw StateError('TokenStore must be overridden in bootstrap');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('AppDatabase must be overridden in bootstrap');
});

/// Entitlements select a data scope, never a user-controlled mode toggle.
final driverOrganizationIdProvider = Provider<String?>((ref) {
  if (ref.watch(currentUserIdProvider) == null ||
      ref.watch(appConfigProvider).mockAuth) {
    return null;
  }
  final organization = ref
      .watch(entitlementsProvider)
      .valueOrNull
      ?.organization;
  return organization?.isDriver == true ? organization!.id : null;
});

final organizationDatabaseProvider = Provider.family<AppDatabase, String>((
  ref,
  scope,
) {
  final db = AppDatabase.scoped('dco_org_$scope');
  ref.onDispose(() {
    unawaited(db.close());
  });
  return db;
});

final recordDatabaseProvider = Provider<AppDatabase>((ref) {
  final organizationId = ref.watch(driverOrganizationIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (organizationId == null || userId == null) {
    return ref.watch(appDatabaseProvider);
  }
  return ref.watch(organizationDatabaseProvider('${userId}_$organizationId'));
});

final recordAdminLockProvider = StreamProvider.family<bool, String>((ref, key) {
  if (ref.watch(driverOrganizationIdProvider) == null) {
    return Stream.value(false);
  }
  final db = ref.watch(recordDatabaseProvider);
  return (db.select(db.appMeta)
        ..where((row) => row.key.equals('org_record:$key')))
      .watchSingleOrNull()
      .map((row) {
        if (row?.value == null) return false;
        final metadata = jsonDecode(row!.value!) as Map<String, dynamic>;
        return metadata['admin_corrected_by'] != null ||
            metadata['source_id'] != null;
      });
});

final adminCorrectedRecordProvider = StreamProvider.family<bool, String>((
  ref,
  key,
) {
  if (ref.watch(driverOrganizationIdProvider) == null) {
    return Stream.value(false);
  }
  final db = ref.watch(recordDatabaseProvider);
  return (db.select(
    db.appMeta,
  )..where((row) => row.key.equals('org_record:$key'))).watchSingleOrNull().map(
    (row) =>
        row?.value != null &&
        (jsonDecode(row!.value!)
                as Map<String, dynamic>)['admin_corrected_by'] !=
            null,
  );
});

/// Submission status remains available after assignment access is removed.
final organizationReviewsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  if (ref.watch(driverOrganizationIdProvider) == null) {
    return Stream.value(const []);
  }
  final db = ref.watch(recordDatabaseProvider);
  return (db.select(
    db.appMeta,
  )..where((row) => row.key.like('org_review:%'))).watch().map(
    (rows) => rows
        .where((row) => row.value != null)
        .map((row) => jsonDecode(row.value!) as Map<String, dynamic>)
        .toList(),
  );
});

final analyticsProvider = Provider<Analytics>((ref) => const Analytics());

final localNotificationClientProvider = Provider<LocalNotificationClient>((
  ref,
) {
  return FlutterLocalNotificationClient();
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokens = ref.watch(tokenStoreProvider);
  final client = DioClient(
    config: config,
    tokenStore: tokens,
    refreshTokens: () async {
      final refresh = await tokens.readRefreshToken();
      if (refresh == null) return null;
      final bare = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      try {
        final response = await bare.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refresh_token': refresh},
        );
        final session = Session.fromJson(response.data!);
        await tokens.writeSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userJson: jsonEncode(session.user.toJson()),
        );
        // §6.3: the access-JWT iat is a server-attested time anchor —
        // advance max_seen so a wrong device clock can't stretch a
        // license window.
        final issuedAt = jwtIssuedAt(session.accessToken);
        if (issuedAt != null) {
          unawaited(
            TrustedClock(
              store: ref.read(licenseStoreProvider),
              userId: session.user.id,
            ).observe(issuedAt),
          );
        }
        return (
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
      } on DioException catch (error) {
        if (error.response?.statusCode == 429 ||
            error.response?.statusCode == 503) {
          rethrow;
        }
        if (error.response?.statusCode == 401) {
          await tokens.clear();
        }
        return null;
      }
    },
  );
  return client.dio;
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.mockAuth) {
    return MockAuthRemoteDataSource();
  }
  return DioAuthRemoteDataSource(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final outboxWriterProvider = Provider<OutboxWriter>((ref) {
  final db = ref.watch(recordDatabaseProvider);
  return ref.watch(driverOrganizationIdProvider) == null
      ? OutboxWriter(db)
      : OrganizationOutboxWriter(db);
});

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final syncApiProvider = Provider<SyncApi>((ref) {
  final organizationId = ref.watch(driverOrganizationIdProvider);
  final dio = ref.watch(dioProvider);
  final db = ref.watch(recordDatabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  final delegate = organizationId == null
      ? DioSyncApi(dio)
      : OrganizationSyncApi(dio, db, organizationId, userId!);
  return userId == null
      ? delegate
      : CurrencySyncApi(
          delegate,
          dio,
          db,
          userId,
          organizationId: organizationId,
        );
});

final currencyConflictRepositoryProvider =
    Provider<CurrencyConflictRepository?>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return null;
      final orgId = ref.watch(driverOrganizationIdProvider);
      final db = ref.watch(recordDatabaseProvider);
      final dio = ref.watch(dioProvider);
      return CurrencyConflictRepository(db, userId, (vehicleId) async {
        if (ref.read(currentUserIdProvider) != userId ||
            ref.read(driverOrganizationIdProvider) != orgId) {
          throw StateError(
            'Account changed. Reopen the draft in its original account.',
          );
        }
        final path = orgId != null
            ? '/organizations/$orgId/currency'
            : vehicleId == null
            ? '/me/currency'
            : '/vehicles/$vehicleId/currency';
        final response = await dio.get<Map<String, dynamic>>(path);
        if (ref.read(currentUserIdProvider) != userId ||
            ref.read(driverOrganizationIdProvider) != orgId) {
          throw StateError(
            'Account changed. Reopen the draft in its original account.',
          );
        }
        return response.data!;
      });
    });

final mediaApiProvider = Provider<MediaApi>((ref) {
  return DioMediaApi(ref.watch(dioProvider));
});

final documentFileProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, documentId) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return Future.value(null);
    return cacheDocument(
      dio: ref.watch(dioProvider),
      db: ref.watch(recordDatabaseProvider),
      userId: userId,
      documentId: documentId,
      organizationId: ref.watch(driverOrganizationIdProvider),
    );
  },
);

final mediaUrlProvider = FutureProvider.family<String?, String>((
  ref,
  mediaId,
) async {
  if (mediaId.isEmpty) return null;
  final api = ref.watch(mediaApiProvider);
  final media = await api.get(mediaId);
  return media.downloadUrl;
});

final syncAccountCoordinatorProvider = Provider<SyncAccountCoordinator>(
  (ref) => SyncAccountCoordinator(),
);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(recordDatabaseProvider),
    api: ref.watch(syncApiProvider),
    mediaApi: ref.watch(mediaApiProvider),
    currentUser: () {
      if (!ref.read(appConfigProvider).mockAuth &&
          ref.read(entitlementsProvider).valueOrNull == null) {
        return null;
      }
      return ref.read(sessionControllerProvider).valueOrNull?.user.id;
    },
    outbox: ref.watch(outboxWriterProvider),
    applier: ChangeApplier(
      ref.watch(recordDatabaseProvider),
      authoritative: ref.watch(driverOrganizationIdProvider) != null,
    ),
    batchSize: ref.watch(driverOrganizationIdProvider) == null ? 25 : 1,
    autoSyncEnabled: () => ref.read(autoSyncProvider),
  );
  final coordinator = ref.read(syncAccountCoordinatorProvider);
  coordinator.register(engine);
  // Every account/organization scope gets a fresh engine. Start that instance
  // directly; an entitlement listener can otherwise schedule the old engine
  // just before its dependencies replace and dispose it.
  engine.requestSync();
  ref.onDispose(() {
    coordinator.unregister(engine);
    engine.dispose();
  });
  return engine;
});

final syncStatusProvider = StreamProvider<SyncState>((ref) {
  return ref.watch(syncEngineProvider).stream;
});

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.mockAuth) {
    return MockProfileRemoteDataSource();
  }
  return DioProfileRemoteDataSource(ref.watch(dioProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    remote: ref.watch(profileRemoteDataSourceProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

final licenseRepositoryProvider = Provider<LicenseRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.mockAuth) {
    return MockLicenseRepository();
  }
  return LicenseRepositoryImpl(ref.watch(dioProvider));
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepositoryImpl(
    db: ref.watch(recordDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepositoryImpl(
    db: ref.watch(recordDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
    syncEngine: ref.watch(syncEngineProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
  );
});

final maintenanceCatalogRepositoryProvider =
    Provider<MaintenanceCatalogRepository>((ref) {
      return MaintenanceCatalogRepositoryImpl(
        db: ref.watch(recordDatabaseProvider),
        dio: ref.watch(dioProvider),
      );
    });

final partsRepositoryProvider = Provider<PartsRepository>((ref) {
  return PartsRepositoryImpl(
    db: ref.watch(recordDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepositoryImpl(db: ref.watch(recordDatabaseProvider));
});

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  return FuelRepositoryImpl(
    db: ref.watch(recordDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
    syncEngine: ref.watch(syncEngineProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
  );
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(
    db: ref.watch(recordDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(
    db: ref.watch(recordDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepositoryImpl(ref.watch(appDatabaseProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
  );
});

final reminderScheduleStoreProvider = Provider<ReminderScheduleStore>((ref) {
  return ReminderScheduleStore(ref.watch(appDatabaseProvider));
});

final reminderSyncServiceProvider = Provider<ReminderSyncService>((ref) {
  return ReminderSyncService(
    notifications: ref.watch(localNotificationClientProvider),
    notificationsRepo: ref.watch(notificationRepositoryProvider),
    schedules: ref.watch(reminderScheduleStoreProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

final currentUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  return session?.user.id;
});

/// Refresh profile after an account-level mutation without coupling screens to
/// the authentication presentation controller.
final refreshAccountProfileProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => ref.read(sessionControllerProvider.notifier).refreshAccount(),
);

final authUserProvider = Provider((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  return session?.user;
});

// ---------------------------------------------------------------------------
// Auto-sync preference (persisted in AppMeta, per user)
// ---------------------------------------------------------------------------

class AutoSyncNotifier extends StateNotifier<bool> {
  AutoSyncNotifier(this._db, this._userId) : super(true) {
    _load();
  }

  final AppDatabase _db;
  final String? _userId;

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    final key = 'auto_sync:$userId';
    final row = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    if (row != null) {
      state = row.value != 'false';
    }
  }

  Future<void> toggle() async {
    state = !state;
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    final key = 'auto_sync:$userId';
    final existing = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.appMeta,
      )..where((m) => m.id.equals(existing.id))).write(
        AppMetaCompanion(value: Value<String?>(state ? 'true' : 'false')),
      );
    } else {
      await _db
          .into(_db.appMeta)
          .insert(
            AppMetaCompanion.insert(
              key: key,
              value: Value<String?>(state ? 'true' : 'false'),
            ),
          );
    }
  }
}

final autoSyncProvider = StateNotifierProvider<AutoSyncNotifier, bool>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final db = ref.watch(appDatabaseProvider);
  return AutoSyncNotifier(db, userId);
});

// ---------------------------------------------------------------------------
// Pending outbox count (reactive — recalculated on each sync cycle)
// ---------------------------------------------------------------------------

final pendingOutboxCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) return 0;
  final db = ref.watch(recordDatabaseProvider);
  final rows =
      await (db.select(db.outboxEntries)..where(
            (row) =>
                row.userId.equals(userId) &
                row.parked.equals(false) &
                row.attemptCount.isSmallerOrEqualValue(4),
          ))
          .get();
  return rows.length;
});

/// Rows parked by a `LIMIT_EXCEEDED` rejection — surfaced on the sync
/// screen until a fresh license requeues them (feature-gating §9).
final parkedOutboxCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) return 0;
  final db = ref.watch(recordDatabaseProvider);
  final rows = await (db.select(
    db.outboxEntries,
  )..where((row) => row.userId.equals(userId) & row.parked.equals(true))).get();
  return rows.length;
});

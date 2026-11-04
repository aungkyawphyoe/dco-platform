import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../notifications/local_notification_client.dart';
import 'token_store.dart';

final accountTransitionProvider = StateProvider<bool>((ref) => false);
final accountLockProvider = StateProvider<String?>((ref) => null);
final accountCleanupPendingProvider = StateProvider<bool>((ref) => false);
final accountEpochProvider = StateProvider<int>((ref) => 0);

abstract class LifecycleJournal {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

class MemoryLifecycleJournal implements LifecycleJournal {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    this.value = {...value};
  }
}

class FileLifecycleJournal implements LifecycleJournal {
  FileLifecycleJournal(this.file);
  final File file;
  Future<void> _pending = Future.value();
  @override
  Future<Map<String, dynamic>?> read() async {
    await _pending;
    return await file.exists()
        ? jsonDecode(await file.readAsString()) as Map<String, dynamic>
        : null;
  }

  @override
  Future<void> write(Map<String, dynamic> value) {
    final bytes = jsonEncode(value);
    final result = _pending.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(bytes, flush: true);
      await temporary.rename(file.path);
    });
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

class PendingAccountData {
  PendingAccountData(this.items, {this.canDiscard = false});
  final List<String> items;
  final bool canDiscard;
  bool get isEmpty => items.isEmpty;
}

class LogoutSyncFailure implements Exception {
  LogoutSyncFailure(this.pending);
  final PendingAccountData pending;
}

/// A journal survives an interrupted cleanup but is removed by uninstall.
/// Its installation marker is technical state, never an account preference.
class AccountLifecycle {
  AccountLifecycle({
    required this.primary,
    required this.tokens,
    required this.notifications,
    required this.journal,
    required this.clearSecrets,
    this.cleanFiles,
    this.discoverDatabases,
  });
  final AppDatabase primary;
  final TokenStore tokens;
  final LocalNotificationClient notifications;
  final LifecycleJournal journal;
  final Future<void> Function() clearSecrets;
  final Future<void> Function()? cleanFiles;
  final Future<List<AppDatabase>> Function()? discoverDatabases;
  final Map<AppDatabase, String?> _databases = {};
  Future<void>? _initialization;
  String? lockedUserId;
  bool cleanupPending = false;

  void register(AppDatabase database, [String? name]) =>
      _databases[database] = name;
  void unregister(AppDatabase database) => _databases.remove(database);
  Iterable<AppDatabase> get databases => {primary, ..._databases.keys};

  Future<void> initialize() => _initialization ??= _initialize().catchError((
    Object error,
    StackTrace stack,
  ) {
    cleanupPending = true;
    Error.throwWithStackTrace(error, stack);
  });
  Future<void> _initialize() async {
    final saved = await journal.read();
    lockedUserId = saved?['locked_user_id'] as String?;
    cleanupPending = saved?['cleanup_pending'] == true;
    if (saved == null) {
      final profiles = await primary.select(primary.userProfiles).get();
      final vehicles = await primary.select(primary.vehicleRecords).get();
      final queued = await primary.select(primary.outboxEntries).get();
      final notes = await primary.select(primary.noteRecords).get();
      if (profiles.isEmpty &&
          vehicles.isEmpty &&
          queued.isEmpty &&
          notes.isEmpty) {
        // Keychain credentials can outlive an iOS installation.
        await purge();
      } else {
        final cached = await tokens.readUserJson();
        lockedUserId = cached == null
            ? profiles.firstOrNull?.userId
            : (jsonDecode(cached) as Map)['id'] as String?;
        lockedUserId ??=
            queued.firstOrNull?.userId ?? notes.firstOrNull?.userId;
      }
      await _save();
    }
    if (saved != null && lockedUserId == null && !cleanupPending) {
      final profiles = await primary.select(primary.userProfiles).get();
      final queued = await primary.select(primary.outboxEntries).get();
      final cached = await tokens.readUserJson();
      lockedUserId = cached == null
          ? profiles.firstOrNull?.userId ?? queued.firstOrNull?.userId
          : (jsonDecode(cached) as Map)['id'] as String?;
      if (lockedUserId != null) await _save();
    }
    if (cleanupPending) await purge();
  }

  Future<void> lock(String userId) async {
    lockedUserId = userId;
    await _save();
  }

  Future<void> _save() => journal.write({
    'installed': true,
    'locked_user_id': lockedUserId,
    'cleanup_pending': cleanupPending,
  });

  Future<PendingAccountData> pending() async {
    final items = <String>[];
    var rejected = false;
    final additional = await discoverDatabases?.call() ?? <AppDatabase>[];
    try {
      for (final db in {...databases, ...additional}) {
        final rows = await db.select(db.outboxEntries).get();
        rejected |= additional.contains(db) && rows.isNotEmpty;
        for (final row in rows) {
          items.add(row.entityType);
          rejected |=
              row.parked ||
              (row.attemptCount > 0 &&
                  !{
                    'network',
                    'server',
                    'rate_limited',
                    'service_unavailable',
                    'unknown',
                  }.contains(row.errorCode));
        }
        final paths = <String>[];
        for (final row in await db.select(db.vehicleRecords).get()) {
          if (row.photoMediaId == null && row.photoLocalPath != null) {
            paths.add(row.photoLocalPath!);
          }
        }
        for (final row in await db.select(db.serviceRecordRows).get()) {
          if (row.receiptMediaId == null && row.receiptLocalPath != null) {
            paths.add(row.receiptLocalPath!);
          }
        }
        for (final row in await db.select(db.expenseRecords).get()) {
          if (row.receiptMediaId == null && row.receiptLocalPath != null) {
            paths.add(row.receiptLocalPath!);
          }
        }
        for (final row in await db.select(db.documentRecords).get()) {
          if (row.mediaId == null && row.localFilePath != null) {
            paths.add(row.localFilePath!);
          }
        }
        for (final path in paths) {
          items.add('upload');
          rejected |= !await File(path).exists();
          final error =
              await (db.select(db.appMeta)
                    ..where((row) => row.key.equals('media_error:$path')))
                  .getSingleOrNull();
          rejected |=
              error?.value != null &&
              !{
                'network',
                'server',
                'rate_limited',
                'service_unavailable',
                'unknown',
              }.contains(error!.value);
        }
      }
    } finally {
      for (final db in additional) {
        await db.close();
      }
    }
    return PendingAccountData(
      items,
      canDiscard:
          rejected ||
          cleanupPending ||
          lockedUserId != null && await tokens.readRefreshToken() == null,
    );
  }

  Future<void> purge() async {
    cleanupPending = true;
    await _save();
    await tokens.clear();
    await clearSecrets();
    await notifications.cancelAll();
    final additional = await discoverDatabases?.call() ?? <AppDatabase>[];
    try {
      for (final db in {...databases, ...additional}) {
        await db.transaction(() async {
          for (final table in db.allTables.toList().reversed) {
            await db.customStatement('DELETE FROM "${table.actualTableName}"');
          }
        });
        await db.customStatement('VACUUM');
        await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      }
      await cleanFiles?.call();
    } finally {
      for (final db in additional) {
        await db.close();
      }
    }
    await journal.write({
      'installed': true,
      'locked_user_id': null,
      'cleanup_pending': false,
    });
    lockedUserId = null;
    cleanupPending = false;
    _initialization = Future.value();
  }

  Future<List<AppDatabase>> openInactiveDatabases() async {
    final activeNames = _databases.values.whereType<String>().toSet();
    final opened = <AppDatabase>[];
    final roots = {
      (await getApplicationDocumentsDirectory()).path,
      (await getApplicationSupportDirectory()).path,
    };
    for (final root in roots) {
      await for (final entity in Directory(root).list()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is File &&
            name.startsWith('dco_org_') &&
            name.endsWith('.sqlite') &&
            !activeNames.contains(name.substring(0, name.length - 7))) {
          opened.add(AppDatabase(NativeDatabase(entity)));
        }
      }
    }
    return opened;
  }
}

Future<void> cleanAccountFiles({
  Directory? documentsDirectory,
  Directory? supportDirectory,
  Directory? temporaryDirectory,
}) async {
  final documents =
      documentsDirectory ?? await getApplicationDocumentsDirectory();
  final support = supportDirectory ?? await getApplicationSupportDirectory();
  final temporary = temporaryDirectory ?? await getTemporaryDirectory();
  for (final directory in [
    for (final name in [
      'vehicles',
      'expenses',
      'documents',
      'receipts',
      'services',
    ])
      Directory('${documents.path}/$name'),
    Directory('${support.path}/documents'),
  ]) {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
  if (await temporary.exists()) {
    await for (final child in temporary.list()) {
      await child.delete(recursive: true);
    }
  }
}

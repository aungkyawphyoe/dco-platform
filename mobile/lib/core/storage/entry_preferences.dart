import 'dart:ui';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers.dart';

class EntryPreferences {
  const EntryPreferences({required this.language, this.completed = false});
  final String language;
  final bool completed;
}

final entryPreferencesProvider =
    AsyncNotifierProvider<EntryPreferencesController, EntryPreferences>(
      EntryPreferencesController.new,
    );

class EntryPreferencesController extends AsyncNotifier<EntryPreferences> {
  @override
  Future<EntryPreferences> build() async {
    final db = ref.read(appDatabaseProvider);
    final rows = await (db.select(
      db.appMeta,
    )..where((r) => r.key.isIn(['entry.language', 'entry.completed']))).get();
    final values = {for (final row in rows) row.key: row.value};
    return EntryPreferences(
      language:
          values['entry.language'] ??
          (PlatformDispatcher.instance.locale.languageCode == 'my'
              ? 'my'
              : 'en'),
      completed: values['entry.completed'] == 'true',
    );
  }

  Future<void> _save(String key, String value) async {
    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      final row = await (db.select(
        db.appMeta,
      )..where((r) => r.key.equals(key))).getSingleOrNull();
      if (row == null) {
        await db
            .into(db.appMeta)
            .insert(AppMetaCompanion.insert(key: key, value: Value(value)));
      } else {
        await (db.update(db.appMeta)..where((r) => r.id.equals(row.id))).write(
          AppMetaCompanion(value: Value(value)),
        );
      }
    });
  }

  Future<void> language(String value) async {
    final current = state.valueOrNull ?? await future;
    await _save('entry.language', value);
    state = AsyncData(
      EntryPreferences(language: value, completed: current.completed),
    );
  }

  Future<void> complete() async {
    final current = state.valueOrNull ?? await future;
    await _save('entry.completed', 'true');
    state = AsyncData(
      EntryPreferences(language: current.language, completed: true),
    );
  }

  Future<void> initializeAccountLanguage(String userId) async {
    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(
      db.userProfiles,
    )..where((r) => r.userId.equals(userId))).getSingleOrNull();
    if (row == null) {
      final prefs = state.valueOrNull ?? await future;
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              userId: userId,
              language: Value(prefs.language),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}

// Transient navigation only; no tokens are persisted here.
final postAuthRouteProvider = StateProvider<String?>((ref) => null);
final newOwnerSetupProvider = StateProvider<bool>((ref) => false);
final pendingCollaborationProvider = StateProvider<String?>((ref) => null);
final pendingSocialLinkProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

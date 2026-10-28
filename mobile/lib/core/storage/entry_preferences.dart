import 'dart:ui';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers.dart';

class EntryPreferences {
  const EntryPreferences({
    required this.language,
    this.completed = false,
    this.themeMode,
  });

  final String language;
  final bool completed;

  /// Last Light / Dark / System choice made on this device (`light`, `dark`,
  /// `system`). Kept outside the account row so the splash, introduction and
  /// auth screens use the same theme after logout. `null` until the user
  /// chooses for the first time; callers fall back to `system`.
  final String? themeMode;
}

final entryPreferencesProvider =
    AsyncNotifierProvider<EntryPreferencesController, EntryPreferences>(
      EntryPreferencesController.new,
    );

/// Theme code read synchronously during bootstrap (before the async entry
/// preferences settle). Keeps the first Flutter frame — the splash — on the
/// saved appearance instead of System.
final initialEntryThemeProvider = Provider<String?>((ref) => null);

class EntryPreferencesController extends AsyncNotifier<EntryPreferences> {
  @override
  Future<EntryPreferences> build() async {
    final db = ref.read(appDatabaseProvider);
    final query = db.select(db.appMeta)
      ..where(
        (r) => r.key.isIn(['entry.language', 'entry.completed', 'entry.theme']),
      );
    final rows = await query.get();
    final values = {for (final row in rows) row.key: row.value};
    return EntryPreferences(
      language:
          values['entry.language'] ??
          (PlatformDispatcher.instance.locale.languageCode == 'my'
              ? 'my'
              : 'en'),
      completed: values['entry.completed'] == 'true',
      themeMode: values['entry.theme'],
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
      EntryPreferences(
        language: value,
        completed: current.completed,
        themeMode: current.themeMode,
      ),
    );
  }

  Future<void> complete() async {
    final current = state.valueOrNull ?? await future;
    await _save('entry.completed', 'true');
    state = AsyncData(
      EntryPreferences(
        language: current.language,
        completed: true,
        themeMode: current.themeMode,
      ),
    );
  }

  /// Persists the device-wide appearance choice so it survives logout and
  /// applies before a session exists (splash, introduction, login, signup).
  Future<void> themeMode(String value) async {
    final current = state.valueOrNull ?? await future;
    await _save('entry.theme', value);
    state = AsyncData(
      EntryPreferences(
        language: current.language,
        completed: current.completed,
        themeMode: value,
      ),
    );
  }

  /// Seeds a new account row with the device-wide entry choices so the app
  /// keeps its current language and appearance right after signup.
  Future<void> initializeAccountPreferences(String userId) async {
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
              themeMode: Value(prefs.themeMode ?? 'system'),
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

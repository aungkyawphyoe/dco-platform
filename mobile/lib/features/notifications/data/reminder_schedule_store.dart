import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/reminder_policy.dart';
import '../domain/reminder_planner.dart';

/// Persists which plan-item phases already have a future OS alarm.
///
/// Key: `reminder.schedule.<planItemId>.<phase>` → `"<cycleKey>|<fireAt ISO8601>"`.
/// Legacy keys without a phase suffix (`reminder.schedule.<planItemId>`) are
/// read as [ReminderPhase.due] and removed on the next write.
class ReminderScheduleStore {
  ReminderScheduleStore(this._db);

  final AppDatabase _db;

  static const _prefix = 'reminder.schedule.';
  static const _permissionAskedKey = 'reminder.permission.asked';

  Future<List<ScheduledReminder>> all() async {
    final rows = await (_db.select(_db.appMeta)
          ..where((row) => row.key.like('$_prefix%')))
        .get();
    final result = <ScheduledReminder>[];
    for (final row in rows) {
      final value = row.value;
      if (value == null || value.isEmpty) continue;
      final parts = value.split('|');
      if (parts.length < 2) continue;
      // The cycle key itself contains one `|` (`<date>|<miles>`), so the
      // fire time is the trailing segment and the rest is the cycle key.
      final fireAt = DateTime.tryParse(parts.last);
      if (fireAt == null) continue;
      final cycleKey = parts.sublist(0, parts.length - 1).join('|');
      final rest = row.key.substring(_prefix.length);
      final dot = rest.lastIndexOf('.');
      final planItemId = dot == -1 ? rest : rest.substring(0, dot);
      final phase = dot == -1
          ? ReminderPhase.due
          : ReminderPhase.values.asNameMap()[rest.substring(dot + 1)];
      if (planItemId.isEmpty || phase == null) continue;
      result.add(
        ScheduledReminder(
          planItemId: planItemId,
          phase: phase,
          cycleKey: cycleKey,
          fireAt: fireAt,
        ),
      );
    }
    return result;
  }

  Future<void> markScheduled({
    required String planItemId,
    required ReminderPhase phase,
    required String cycleKey,
    required DateTime fireAt,
  }) async {
    await _deleteLegacy(planItemId);
    return _upsert(
      _key(planItemId, phase),
      '$cycleKey|${fireAt.toIso8601String()}',
    );
  }

  Future<void> clear(String planItemId, ReminderPhase phase) async {
    await _deleteLegacy(planItemId);
    await (_db.delete(_db.appMeta)..where((row) => row.key.equals(_key(planItemId, phase))))
        .go();
  }

  Future<bool> get permissionAsked async {
    final row = await (_db.select(_db.appMeta)
          ..where((row) => row.key.equals(_permissionAskedKey)))
        .getSingleOrNull();
    return row?.value == '1';
  }

  Future<void> markPermissionAsked() => _upsert(_permissionAskedKey, '1');

  String _key(String planItemId, ReminderPhase phase) =>
      '$_prefix$planItemId.${phase.name}';

  Future<void> _deleteLegacy(String planItemId) {
    return (_db.delete(_db.appMeta)..where((row) => row.key.equals('$_prefix$planItemId')))
        .go();
  }

  Future<void> _upsert(String key, String value) async {
    final existing = await (_db.select(_db.appMeta)..where((row) => row.key.equals(key)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.appMeta)..where((row) => row.id.equals(existing.id))).write(
        AppMetaCompanion(value: Value(value)),
      );
      return;
    }
    await _db.into(_db.appMeta).insert(AppMetaCompanion.insert(key: key, value: Value(value)));
  }
}

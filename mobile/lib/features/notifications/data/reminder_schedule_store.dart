import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/reminder_planner.dart';

/// Persists which plan-item cycles already have a future OS alarm.
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
      final fireAt = DateTime.tryParse(parts.sublist(1).join('|'));
      if (fireAt == null) continue;
      result.add(
        ScheduledReminder(
          planItemId: row.key.substring(_prefix.length),
          cycleKey: parts[0],
          fireAt: fireAt,
        ),
      );
    }
    return result;
  }

  Future<void> markScheduled({
    required String planItemId,
    required String cycleKey,
    required DateTime fireAt,
  }) {
    return _upsert('$_prefix$planItemId', '$cycleKey|${fireAt.toIso8601String()}');
  }

  Future<void> clear(String planItemId) {
    return (_db.delete(_db.appMeta)..where((row) => row.key.equals('$_prefix$planItemId'))).go();
  }

  Future<bool> get permissionAsked async {
    final row = await (_db.select(_db.appMeta)
          ..where((row) => row.key.equals(_permissionAskedKey)))
        .getSingleOrNull();
    return row?.value == '1';
  }

  Future<void> markPermissionAsked() => _upsert(_permissionAskedKey, '1');

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

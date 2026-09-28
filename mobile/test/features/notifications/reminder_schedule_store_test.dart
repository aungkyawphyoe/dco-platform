import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/notifications/data/reminder_schedule_store.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReminderScheduleStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = ReminderScheduleStore(db);
  });

  tearDown(() => db.close());

  test('stores and reads schedules per phase', () async {
    await store.markScheduled(
      planItemId: 'p1',
      phase: ReminderPhase.upcoming,
      cycleKey: '2026-09-01|',
      fireAt: DateTime(2026, 8, 2, 9),
    );
    await store.markScheduled(
      planItemId: 'p1',
      phase: ReminderPhase.due,
      cycleKey: '2026-09-01|',
      fireAt: DateTime(2026, 9, 1, 9),
    );

    final all = await store.all();
    expect(all, hasLength(2));
    final upcoming = all.singleWhere((row) => row.phase == ReminderPhase.upcoming);
    expect(upcoming.planItemId, 'p1');
    expect(upcoming.cycleKey, '2026-09-01|');
    expect(upcoming.fireAt, DateTime(2026, 8, 2, 9));
    final due = all.singleWhere((row) => row.phase == ReminderPhase.due);
    expect(due.fireAt, DateTime(2026, 9, 1, 9));

    await store.clear('p1', ReminderPhase.upcoming);
    final remaining = await store.all();
    expect(remaining.single.phase, ReminderPhase.due);
  });

  test('reads legacy unphased keys as due and drops them on the next write', () async {
    await db.into(db.appMeta).insert(
      AppMetaCompanion.insert(
        key: 'reminder.schedule.p1',
        value: const Value('2026-09-01|2026-09-01T09:00:00.000'),
      ),
    );

    final legacy = await store.all();
    expect(legacy.single.planItemId, 'p1');
    expect(legacy.single.phase, ReminderPhase.due);
    expect(legacy.single.fireAt, DateTime.parse('2026-09-01T09:00:00.000'));

    await store.clear('p1', ReminderPhase.due);
    expect(await store.all(), isEmpty);
  });

  test('tracks the permission prompt flag', () async {
    expect(await store.permissionAsked, isFalse);
    await store.markPermissionAsked();
    expect(await store.permissionAsked, isTrue);
  });
}

import 'dart:ui';

import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/notifications/data/reminder_copy.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  late ReminderCopy en;

  setUp(() async {
    en = ReminderCopy(const Locale('en'));
    await en.ensureInitialized();
  });

  test('titles are phase-specific', () {
    expect(en.title(ReminderPhase.upcoming), 'Upcoming maintenance');
    expect(en.title(ReminderPhase.due), 'Maintenance due');
  });

  test('titles follow the locale', () async {
    final my = ReminderCopy(const Locale('my'));
    await my.ensureInitialized();
    final strings = lookupAppLocalizations(const Locale('my'));
    expect(my.title(ReminderPhase.upcoming), strings.notificationsReminderUpcomingTitle);
    expect(my.title(ReminderPhase.due), strings.notificationsReminderDueTitle);
    expect(my.title(ReminderPhase.due), isNot(en.title(ReminderPhase.due)));
  });

  test('body carries the name and the due date', () {
    final date = DateTime(2026, 9, 20);
    final body = en.body(name: 'Oil Change', dueOn: date, unit: MileageUnit.mi);
    expect(body, contains('Oil Change'));
    expect(body, contains(DateFormat.yMMMd('en').format(date)));
  });

  test('body carries the name and the due mileage in the owner unit', () {
    final body = en.body(
      name: 'Oil Change',
      dueMileage: MileageUnit.km.toStorage(100000),
      unit: MileageUnit.km,
    );
    expect(body, contains('Oil Change'));
    expect(body, contains('100,000 km'));
  });

  test('body carries date and mileage when the item has both', () {
    final date = DateTime(2026, 9, 20);
    final body = en.body(
      name: 'Oil Change',
      dueOn: date,
      dueMileage: 62000,
      unit: MileageUnit.mi,
    );
    expect(body, contains('Oil Change'));
    expect(body, contains(DateFormat.yMMMd('en').format(date)));
    expect(body, contains('62,000 mi'));
  });

  test('body falls back to the name when the item has no due values', () {
    expect(en.body(name: 'Oil Change', unit: MileageUnit.mi), 'Oil Change');
  });

  test('body is clipped to the policy maximum', () {
    final body = en.body(
      name: 'x' * 200,
      dueOn: DateTime(2026, 9, 20),
      unit: MileageUnit.mi,
    );
    expect(body.length, ReminderPolicy.bodyMax);
  });
}

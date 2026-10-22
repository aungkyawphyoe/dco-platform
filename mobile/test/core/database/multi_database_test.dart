import 'package:dco_mobile/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app intentionally keeps the personal database plus one org-scoped
/// database open at the same time for driver accounts (see
/// `organizationDatabaseProvider`). Each instance has its own executor and
/// file, so drift's class-keyed "multiple databases" warning must not fire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('personal + scoped AppDatabase instances coexist without warnings',
      () async {
    final messages = <String>[];
    final previous = driftRuntimeOptions.debugPrint;
    driftRuntimeOptions.debugPrint = messages.add;
    addTearDown(() => driftRuntimeOptions.debugPrint = previous);

    final personal = AppDatabase(NativeDatabase.memory());
    final scoped = AppDatabase(NativeDatabase.memory());

    expect(messages, isEmpty);
    expect(personal, isNot(same(scoped)));

    await personal.close();
    await scoped.close();
  });
}

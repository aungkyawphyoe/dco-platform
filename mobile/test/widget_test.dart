import 'package:dco_mobile/app.dart';
import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('welcome to dashboard via mock sign in', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:8080/v1',
              jwtOwnerAud: 'dco-owner',
              mockAuth: true,
            ),
          ),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const DcoApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Your garage, on the phone.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-sign-in')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'owner@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password12');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Register a vehicle'), findsWidgets);

    await tester.tap(find.byKey(const Key('register-vehicle-cta')));
    await tester.pumpAndSettle();

    Future<void> fill(String key, String value) async {
      final field = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.enterText(field, value);
    }

    await fill('vehicle-name', 'Daily Driver');
    await fill('vehicle-year', '2022');
    await fill('vehicle-make', 'Toyota');
    await fill('vehicle-model', 'Camry');
    await fill('vehicle-plate', 'ABC123');
    await fill('vehicle-mileage', '45230');
    await tester.ensureVisible(find.text('Petrol'));
    await tester.tap(find.text('Petrol'));
    await tester.ensureVisible(find.byKey(const Key('vehicle-save')));
    await tester.tap(find.byKey(const Key('vehicle-save')));
    await tester.pumpAndSettle();

    expect(find.text('Daily Driver'), findsWidgets);
    expect(find.textContaining('Toyota Camry'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await database.close();
  });
}

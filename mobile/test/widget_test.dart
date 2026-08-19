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
          appDatabaseProvider.overrideWithValue(
            AppDatabase(NativeDatabase.memory()),
          ),
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
  });
}

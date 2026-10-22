import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/app_drawer.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Driver mode hides the personal-only Sharing & Fleet entries
/// (Shared with Me / Join with code) in the drawer, matching
/// `GarageHomeScreen`'s `personal` gate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final db = AppDatabase(NativeDatabase.memory());
  tearDownAll(db.close);

  Future<void> pumpDrawer(WidgetTester tester, {required bool driver}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:8080/v1',
              jwtOwnerAud: 'dco-owner',
              mockAuth: true,
              analyticsEnabled: false,
            ),
          ),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          appDatabaseProvider.overrideWithValue(db),
          driverOrganizationIdProvider.overrideWithValue(driver ? 'org' : null),
        ],
        child: MaterialApp(
          theme: buildDcoTheme(Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: SizedBox(), drawer: AppDrawer()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Driver mode hides Shared with Me and Join with code',
      (tester) async {
    await pumpDrawer(tester, driver: true);
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Shared with Me'), findsNothing);
    expect(find.text('Additional'), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    expect(find.byIcon(Icons.people_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Personal mode still shows Shared with Me and Join with code',
      (tester) async {
    await pumpDrawer(tester, driver: false);
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Shared with Me'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
  });
}

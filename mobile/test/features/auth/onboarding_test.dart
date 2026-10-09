import 'dart:io';
import 'dart:ui' as ui;
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/storage/entry_preferences.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/auth/presentation/screens/introduction_screen.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  test(
    'entry language and completion persist independently of account profiles',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      await container.read(entryPreferencesProvider.future);
      await container.read(entryPreferencesProvider.notifier).language('my');
      await container.read(entryPreferencesProvider.notifier).complete();
      container.invalidate(entryPreferencesProvider);
      final restored = await container.read(entryPreferencesProvider.future);
      expect(restored.language, 'my');
      expect(restored.completed, true);
      await container
          .read(entryPreferencesProvider.notifier)
          .initializeAccountLanguage('new-owner');
      expect((await db.select(db.userProfiles).getSingle()).language, 'my');
      await container.read(entryPreferencesProvider.notifier).language('en');
      await container
          .read(entryPreferencesProvider.notifier)
          .initializeAccountLanguage('new-owner');
      expect((await db.select(db.userProfiles).getSingle()).language, 'my');
      container.dispose();
      await db.close();
    },
  );
  testWidgets(
    'language selection leads to three illustrated pages and skip persists',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final key = GlobalKey();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: Consumer(
            builder: (context, ref, _) {
              final entry = ref.watch(entryPreferencesProvider).valueOrNull;
              return MaterialApp(
                theme: buildDcoTheme(Brightness.light),
                locale: Locale(entry?.language ?? 'en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: RepaintBoundary(
                  key: key,
                  child: const IntroductionScreen(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.text('မြန်မာ'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('A home for your car'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      if (Platform.environment['DCO_CAPTURE_ONBOARDING'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final picture = await boundary.toImage(pixelRatio: 2);
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/dco-onboarding-preview.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Stay one step ahead'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Know where your money goes'), findsOneWidget);
      await tester.tap(find.text('Skip introduction'));
      await tester.pumpAndSettle();
      expect(find.text('Your garage, on the phone.'), findsOneWidget);
      expect(
        (await db.select(db.appMeta).get()).any(
          (row) => row.key == 'entry.completed' && row.value == 'true',
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
}

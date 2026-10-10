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
import 'package:flutter_svg/flutter_svg.dart';
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
    'three illustrated pages with art and skip persists',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final key = GlobalKey();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        if (Platform.environment['DCO_CAPTURE_ONBOARDING'] != '1') return;
        final dark =
            Platform.environment['DCO_CAPTURE_ONBOARDING_DARK'] == '1'
                ? '-dark'
                : '';
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final picture = await boundary.toImage(pixelRatio: 2);
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/dco-onboarding-$name$dark.png').writeAsBytes(
            data!.buffer.asUint8List(),
          );
          picture.dispose();
        });
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: Consumer(
            builder: (context, ref, _) {
              final entry = ref.watch(entryPreferencesProvider).valueOrNull;
              return MaterialApp(
                theme: buildDcoTheme(
                  Platform.environment['DCO_CAPTURE_ONBOARDING_DARK'] == '1'
                      ? Brightness.dark
                      : Brightness.light,
                ),
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
      await settle();
      expect(find.text('A home for your car'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
      await capture('page-1');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await settle();
      expect(find.text('Stay one step ahead'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      await capture('page-2');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await settle();
      expect(find.text('Know where your money goes'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      await capture('page-3');
      await tester.tap(find.text('Skip'));
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

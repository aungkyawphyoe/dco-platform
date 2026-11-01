import 'dart:io';
import 'dart:ui' as ui;
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/onboarding/presentation/screens/help_screen.dart';
import 'package:dco_mobile/features/onboarding/presentation/widgets/feedback_card.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final previewFont = Platform.environment['DCO_HELP_PREVIEW_FONT'];
  setUpAll(() async {
    if (previewFont != null) {
      final loader = FontLoader('HelpPreview');
      loader.addFont(
        File(
          previewFont,
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });

  test('mailto preserves Unicode and punctuation without form encoding', () {
    const body = 'မြန်မာ + test & details\nsecond line';
    final uri = feedbackEmailUri('AutoX feedback', body);
    expect(uri.scheme, 'mailto');
    expect(uri.path, feedbackSupportEmail);
    expect(uri.queryParameters['body'], body);
    expect(uri.query, contains('AutoX%20feedback'));
  });

  testWidgets(
    'feedback keeps draft on launch failure and copies only opted-in data',
    (tester) async {
      Uri? launched;
      String? copied;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackEmailLauncherProvider.overrideWithValue((uri) async {
              launched = uri;
              return false;
            }),
            feedbackClipboardProvider.overrideWithValue((text) async {
              copied = text;
            }),
          ],
          child: MaterialApp(
            theme: buildDcoTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: FeedbackCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(launched, isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('feedback-message')),
        'My feedback & question',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Open email draft'));
      await tester.tap(find.text('Open email draft'));
      await tester.pumpAndSettle();
      expect(launched!.queryParameters['body'], 'My feedback & question');
      expect(
        find.textContaining('Could not open an email app.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My feedback & question',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copy feedback'));
      await tester.tap(find.text('Copy feedback'));
      await tester.pumpAndSettle();
      expect(copied, contains('To: $feedbackSupportEmail'));
      expect(copied, contains('Platform:'));
      expect(copied, contains('My feedback & question'));
    },
  );

  for (final language in ['en', 'my']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$language $brightness offline help fits a narrow screen with large text',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                driverOrganizationIdProvider.overrideWithValue('org-test'),
              ],
              child: MaterialApp(
                theme: previewFont == null
                    ? buildDcoTheme(brightness)
                    : buildDcoTheme(brightness).copyWith(
                        textTheme: buildDcoTheme(
                          brightness,
                        ).textTheme.apply(fontFamily: 'HelpPreview'),
                      ),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: RepaintBoundary(key: capture, child: const HelpScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final s = AppLocalizations.of(
            tester.element(find.byType(HelpScreen)),
          )!;
          expect(find.text(s.helpReplayTour), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text(s.helpVehicleQuestion),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(s.helpVehicleQuestion));
          await tester.pumpAndSettle();
          expect(find.text(s.helpDriverVehicleAnswer), findsOneWidget);
          expect(find.text(s.helpVehicleAnswer), findsNothing);
          for (var pass = 0; pass < 3; pass++) {
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
          }
          expect(find.text(s.helpFeedbackTitle), findsOneWidget);
          await tester.enterText(
            find.byKey(const Key('feedback-message')),
            'Keep this draft',
          );
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView), const Offset(0, 5000));
          await tester.pumpAndSettle();
          for (var pass = 0; pass < 3; pass++) {
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
          }
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('feedback-message')))
                .controller!
                .text,
            'Keep this draft',
          );
          expect(tester.takeException(), isNull);
          if (Platform.environment['DCO_CAPTURE_HELP'] == '1') {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final picture = await boundary.toImage();
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/autox-help-$language-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
        },
      );
    }
  }
}

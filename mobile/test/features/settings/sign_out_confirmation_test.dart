import 'dart:async';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:dco_mobile/features/settings/presentation/widgets/sign_out_button.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController({this.gate});

  final Completer<void>? gate;
  int signOutCalls = 0;

  @override
  Future<Session?> build() async => null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (gate != null) await gate!.future;
  }
}

void main() {
  late _FakeSessionController controller;

  Future<void> pump(WidgetTester tester, {Widget? home}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(() => controller),
          driverOrganizationIdProvider.overrideWithValue(null),
          userPreferencesProvider.overrideWith(
            (ref) => Stream.value(UserPreferences.defaults),
          ),
        ],
        child: MaterialApp(
          theme: buildDcoTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home ?? const Scaffold(body: SignOutButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations localizations(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byType(SignOutButton));
    await tester.pumpAndSettle();
  }

  testWidgets('Settings sign-out asks for confirmation first', (tester) async {
    controller = _FakeSessionController();
    await pump(tester, home: const Scaffold(body: SettingsScreen()));
    final s = localizations(tester);

    await tester.tap(find.text(s.settingsSignOut));
    await tester.pumpAndSettle();

    expect(find.text(s.settingsSignOutConfirmTitle), findsOneWidget);
    expect(find.text(s.settingsSignOutConfirmBody), findsOneWidget);
    expect(find.text(s.cancel), findsOneWidget);
    expect(controller.signOutCalls, 0);
  });

  testWidgets('Cancel leaves the session unchanged', (tester) async {
    controller = _FakeSessionController();
    await pump(tester);
    final s = localizations(tester);

    await openDialog(tester);
    await tester.tap(find.text(s.cancel));
    await tester.pumpAndSettle();

    expect(find.text(s.settingsSignOutConfirmTitle), findsNothing);
    expect(controller.signOutCalls, 0);
  });

  testWidgets('Dismissing the dialog leaves the session unchanged', (
    tester,
  ) async {
    controller = _FakeSessionController();
    await pump(tester);
    final s = localizations(tester);

    await openDialog(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text(s.settingsSignOutConfirmTitle), findsNothing);
    expect(controller.signOutCalls, 0);
  });

  testWidgets('System Back leaves the session unchanged', (tester) async {
    controller = _FakeSessionController();
    await pump(tester);
    final s = localizations(tester);

    await openDialog(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(s.settingsSignOutConfirmTitle), findsNothing);
    expect(controller.signOutCalls, 0);
  });

  testWidgets('Confirm signs out once and blocks repeat submission', (
    tester,
  ) async {
    final gate = Completer<void>();
    controller = _FakeSessionController(gate: gate);
    await pump(tester);
    final s = localizations(tester);

    await openDialog(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(s.settingsSignOut),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.signOutCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(s.settingsSignOutConfirmTitle), findsNothing);

    // The action is disabled while sign-out runs, so further taps are ignored.
    await tester.tap(find.byType(SignOutButton));
    await tester.pump();
    expect(controller.signOutCalls, 1);
    expect(find.text(s.settingsSignOutConfirmTitle), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(controller.signOutCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

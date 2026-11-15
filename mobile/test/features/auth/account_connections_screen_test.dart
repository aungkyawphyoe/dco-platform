import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:dco_mobile/features/auth/presentation/screens/account_connections_screen.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _VerifiedSession extends SessionController {
  @override
  Future<Session?> build() async => const Session(
    accessToken: 'access',
    refreshToken: 'refresh',
    user: User(
      id: 'owner',
      email: 'owner@example.test',
      username: 'owner',
      role: 'owner',
      plan: 'free',
      status: 'active',
      emailVerified: true,
      mustChangePassword: false,
    ),
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final locale in const [Locale('en'), Locale('my')]) {
    for (final brightness in Brightness.values) {
      for (final connected in [false, true]) {
        testWidgets('connections at 320px: $locale $brightness $connected', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sessionControllerProvider.overrideWith(_VerifiedSession.new),
                connectionsProvider.overrideWith(
                  (_) async => {
                    'providers': [if (connected) 'google'],
                    'has_password': !connected,
                  },
                ),
              ],
              child: MaterialApp(
                theme: buildDcoTheme(brightness),
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const AccountConnectionsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final s = AppLocalizations.of(
            tester.element(find.byType(AccountConnectionsScreen)),
          )!;
          expect(
            find.text(s.authConnectGoogle),
            connected ? findsNothing : findsOneWidget,
          );
          expect(
            find.text(s.authLinked),
            connected ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(AuthTextField),
            connected ? findsNWidgets(2) : findsNothing,
          );
          if (connected) {
            await tester.ensureVisible(find.text(s.save));
            await tester.tap(find.text(s.save));
            await tester.pumpAndSettle();
            expect(find.text(s.authPasswordMismatch), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

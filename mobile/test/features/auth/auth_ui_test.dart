import 'dart:io';
import 'dart:ui' as ui;

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:dco_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:dco_mobile/features/auth/presentation/screens/signup_screen.dart';
import 'package:dco_mobile/features/auth/presentation/widgets/auth_divider.dart';
import 'package:dco_mobile/features/auth/presentation/widgets/auth_terms_footer.dart';
import 'package:dco_mobile/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:dco_mobile/features/auth/presentation/widgets/social_buttons.dart';
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

  Future<AppDatabase> pumpAuthScreen(
    WidgetTester tester,
    Widget screen, {
    required GlobalKey key,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dark = Platform.environment['DCO_CAPTURE_AUTH_DARK'] == '1';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildDcoTheme(dark ? Brightness.dark : Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepaintBoundary(key: key, child: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['DCO_CAPTURE_AUTH'] != '1') return;
    final dark =
        Platform.environment['DCO_CAPTURE_AUTH_DARK'] == '1' ? '-dark' : '';
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await boundary.toImage(pixelRatio: 2);
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/dco-auth-$name$dark.png').writeAsBytes(
        data!.buffer.asUint8List(),
      );
      picture.dispose();
    });
  }

  testWidgets('login screen follows the reference layout', (tester) async {
    final key = GlobalKey();
    final db = await pumpAuthScreen(tester, const LoginScreen(), key: key);

    expect(find.text('Sign in'), findsNWidgets(2)); // heading + submit
    expect(
      find.textContaining('New user?', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.byType(AuthTextField), findsNWidgets(2));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.byType(AuthDivider), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    expect(find.text('Continue with a social account'), findsOneWidget);
    expect(find.byType(SocialButtons), findsOneWidget);
    expect(find.byKey(const Key('social-google')), findsOneWidget);
    expect(find.byKey(const Key('social-apple')), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(find.byType(AuthTermsFooter), findsOneWidget);
    expect(
      find.textContaining('Terms of Service', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Privacy Policy', findRichText: true),
      findsOneWidget,
    );
    await capture(tester, key, 'login');
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('signup screen follows the reference layout', (tester) async {
    final key = GlobalKey();
    final db = await pumpAuthScreen(tester, const SignupScreen(), key: key);

    expect(find.text('Create account'), findsNWidgets(2)); // heading + submit
    expect(
      find.textContaining('Already have an account?', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(AuthTextField), findsNWidgets(3));
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byKey(const Key('signup-submit')), findsOneWidget);
    expect(find.byType(AuthDivider), findsOneWidget);
    expect(find.byKey(const Key('social-google')), findsOneWidget);
    expect(find.byKey(const Key('social-apple')), findsOneWidget);
    expect(find.byType(AuthTermsFooter), findsOneWidget);
    await capture(tester, key, 'signup');
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('forgot password uses the shared auth widgets', (tester) async {
    final key = GlobalKey();
    final db = await pumpAuthScreen(
      tester,
      const ForgotPasswordScreen(),
      key: key,
    );

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.byType(AuthTextField), findsOneWidget);
    expect(find.byKey(const Key('forgot-send-code')), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    await capture(tester, key, 'forgot');
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}

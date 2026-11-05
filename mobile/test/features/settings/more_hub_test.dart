import 'package:dco_mobile/features/settings/presentation/screens/preferences_screen.dart';
import 'package:dco_mobile/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:dco_mobile/features/settings/presentation/screens/about_screen.dart';
import 'package:dco_mobile/features/vehicle_sharing/presentation/screens/shared_users_screen.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/entities/shared_users_overview.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/repositories/shared_users_repository.dart';
import 'package:dco_mobile/features/vehicle_sharing/providers.dart';
import 'package:dco_mobile/features/pricing/domain/pricing.dart';
import 'package:dco_mobile/features/pricing/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class EmptySession extends SessionController {
  @override
  Future<Session?> build() async => null;
}

class OwnerSession extends SessionController {
  @override
  Future<Session?> build() async => Session.fromJson({
    'access_token': 'test',
    'refresh_token': 'test',
    'user': {
      'id': 'owner',
      'email': 'owner@example.com',
      'display_name': 'Owner',
      'email_verified': true,
      'role': 'owner',
      'plan': 'free',
      'status': 'active',
    },
  });
}

class MockOverview extends Mock implements SharedUsersRepository {}

class MockPricing extends Mock implements PricingRepository {}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    bool driver = false,
    String locale = 'en',
    Brightness brightness = Brightness.light,
    bool signedIn = false,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        for (final route in [
          AppRoutes.settingsPreferences,
          AppRoutes.about,
          AppRoutes.sharedUsers,
          AppRoutes.parts,
          AppRoutes.fuelTypes,
          AppRoutes.settingsHelp,
          AppRoutes.pricing,
        ])
          GoRoute(
            path: route,
            builder: (_, _) => Scaffold(body: Text('Opened $route')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(
            signedIn ? OwnerSession.new : EmptySession.new,
          ),
          driverOrganizationIdProvider.overrideWithValue(driver ? 'org' : null),
          ...overrides,
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildDcoTheme(brightness),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'More routes to Parts and removes account connection and expense types',
    (tester) async {
      await pump(tester, const SettingsScreen());
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Shared Users'), findsOneWidget);
      expect(find.text('Account connections'), findsNothing);
      expect(find.text('Expense Types'), findsNothing);
      await tester.tap(find.text('Parts'));
      await tester.pumpAndSettle();
      expect(find.text('Opened /parts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Driver More hides sharing and subscriptions', (tester) async {
    await pump(tester, const SettingsScreen(), driver: true);
    expect(find.text('Shared Users'), findsNothing);
    expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
    expect(find.text('Parts'), findsOneWidget);
  });

  testWidgets('nested Settings keeps all four preference destinations', (
    tester,
  ) async {
    await pump(
      tester,
      const PreferencesScreen(),
      overrides: [
        userPreferencesProvider.overrideWith(
          (ref) => Stream.value(UserPreferences.defaults),
        ),
        currencyProvider.overrideWithValue(AppCurrency.mmk),
      ],
    );
    final context = tester.element(find.byType(PreferencesScreen));
    final strings = AppLocalizations.of(context)!;
    for (final title in [
      strings.settingsAppearance,
      strings.settingsLocalization,
      strings.settingsUnitFormat,
      strings.settingsReminders,
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account Connection is available on the owner profile', (
    tester,
  ) async {
    await pump(
      tester,
      const ProfileDetailScreen(userId: 'owner'),
      signedIn: true,
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        userDetailProvider('owner').overrideWith((ref) async => null),
      ],
    );
    final s = AppLocalizations.of(
      tester.element(find.byType(ProfileDetailScreen)),
    )!;
    expect(find.text(s.authConnections), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final locale in ['en', 'my']) {
      testWidgets('More and About fit narrow $locale $brightness screens', (
        tester,
      ) async {
        await pump(
          tester,
          const SettingsScreen(),
          locale: locale,
          brightness: brightness,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await pump(
          tester,
          const AboutScreen(),
          locale: locale,
          brightness: brightness,
          overrides: [
            appPackageInfoProvider.overrideWith(
              (ref) async => PackageInfo(
                appName: 'AutoX',
                packageName: 'com.autox',
                version: '2.3.4',
                buildNumber: '56',
              ),
            ),
          ],
        );
        expect(find.text('www.autoxmm.com'), findsOneWidget);
        expect(find.textContaining('2.3.4'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final limit in <int?>[3, null]) {
    testWidgets(
      'sharing upsell follows quota $limit and cached data survives failure',
      (tester) async {
        final repo = MockOverview();
        final pricing = MockPricing();
        when(repo.refresh).thenThrow(Exception('offline'));
        when(pricing.refresh).thenAnswer((_) async {});
        await pump(
          tester,
          const SharedUsersScreen(),
          overrides: [
            sharedUsersRepositoryProvider.overrideWithValue(repo),
            sharedUsersOverviewProvider.overrideWith(
              (ref) => Stream.value(
                SharedUsersOverview(
                  vehicles: const [],
                  used: 0,
                  limit: limit,
                  updatedAt: DateTime(2026),
                ),
              ),
            ),
            pricingRepositoryProvider.overrideWithValue(pricing),
            pricingPlansProvider.overrideWith(
              (ref) => Stream.value(const [
                PricingPlan(
                  id: 'standard',
                  name: 'Standard',
                  monthly: 1,
                  annual: 10,
                  vehicles: 10,
                  sharing: null,
                  storageBytes: 1,
                ),
              ]),
            ),
          ],
        );
        expect(
          find.text('Need more sharing slots?'),
          limit == null ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Could not refresh. Showing the last saved overview.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

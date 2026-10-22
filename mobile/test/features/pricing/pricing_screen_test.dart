import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:dco_mobile/features/pricing/billing/providers.dart';
import 'package:dco_mobile/features/pricing/billing/play_billing_controller.dart';
import 'package:dco_mobile/features/pricing/domain/play_billing.dart';
import 'package:dco_mobile/core/gating/license_models.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/pricing/domain/pricing.dart';
import 'package:dco_mobile/features/pricing/providers.dart';
import 'package:dco_mobile/features/pricing/presentation/pricing_screen.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/features/pricing/presentation/gift_redemption_screen.dart';

class TestSession extends SessionController {
  TestSession(this.verified);
  final bool verified;
  @override
  Future<Session?> build() async => Session(
    accessToken: 'test',
    refreshToken: 'test',
    user: User(
      id: 'u1',
      email: 'owner@example.com',
      username: 'owner',
      role: 'owner',
      plan: 'free',
      status: 'active',
      emailVerified: verified,
      mustChangePassword: false,
    ),
  );
}

class TestLicense extends LicenseController {
  @override
  Future<EntitlementClaims> build() async => EntitlementClaims.free;
  @override
  Future<void> refreshIfStale({bool force = false}) async {}
}

class TestPricing implements PricingRepository {
  @override
  Stream<List<PricingPlan>?> watchPlans() => Stream.value(const [
    PricingPlan(
      id: 'free',
      name: 'Free',
      monthly: 0,
      annual: 0,
      vehicles: 1,
      sharing: 1,
      storageBytes: 52428800,
    ),
    PricingPlan(
      id: 'lite',
      name: 'Lite',
      monthly: 3000,
      annual: 30000,
      vehicles: 3,
      sharing: 3,
      storageBytes: 157286400,
    ),
    PricingPlan(
      id: 'standard',
      name: 'Standard',
      monthly: 9000,
      annual: 90000,
      vehicles: 10,
      sharing: null,
      storageBytes: 524288000,
    ),
  ]);
  @override
  Stream<SubscriptionStatus?> watchSubscription() =>
      Stream.value(const SubscriptionStatus(plan: 'free'));
  @override
  Future<void> refresh() async {}
  @override
  Future<GiftAccess> redeem(String code) async =>
      throw const RedemptionFailure('code_unavailable');
}

class TestBilling extends PlayBillingController {
  TestBilling(bool supported, {bool demo = false})
    : super(
        store: null,
        backend: null,
        refreshEntitlements: () async => true,
        isCurrentAccount: () => true,
      ) {
    state = PlayBillingState(
      supported: supported,
      canPurchase: supported && !demo,
      message: demo ? 'mock_auth' : null,
      offers: demo
          ? const []
          : const [
              BillingOffer(
                plan: 'standard',
                period: 'monthly',
                price: '\$2.99',
              ),
              BillingOffer(
                plan: 'standard',
                period: 'annual',
                price: '\$29.99',
              ),
            ],
    );
  }
}

void main() {
  Future<void> pumpPricing(
    WidgetTester tester,
    String lang, {
    bool verified = true,
    double scale = 1,
    bool play = false,
    bool demo = false,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: AppRoutes.pricing,
      routes: [
        GoRoute(
          path: AppRoutes.pricing,
          builder: (_, _) => const PricingScreen(),
          routes: [
            GoRoute(
              path: 'redeem',
              builder: (_, _) => const GiftRedemptionScreen(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.verifyEmail,
          builder: (_, _) => const Scaffold(body: Text('Verify email')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final t = lang == 'en'
        ? DcoTokens.garageMinimalDark
        : DcoTokens.garageMinimalLight;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playBillingProvider.overrideWith(
            (ref) => TestBilling(play, demo: demo),
          ),
          pricingRepositoryProvider.overrideWithValue(TestPricing()),
          sessionControllerProvider.overrideWith(() => TestSession(verified)),
          licenseControllerProvider.overrideWith(TestLicense.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            brightness: lang == 'en' ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: t.background.primary,
            extensions: [t],
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'Android demo mode keeps the billing surface discoverable without a native store',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('demo'),
          authUserProvider.overrideWithValue(null),
          licenseKeyringProvider.overrideWith((ref) async => []),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost',
              jwtOwnerAud: 'dco-owner',
              mockAuth: true,
              analyticsEnabled: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final billing = container.read(playBillingProvider);
      expect(billing.supported, true);
      expect(billing.canPurchase, false);
      expect(billing.loading, false);
      expect(billing.message, 'mock_auth');
    },
  );
  testWidgets(
    'demo mode shows disabled subscribe with a reason; Free links to paid plans',
    (tester) async {
      await pumpPricing(tester, 'en', play: true, demo: true);
      final subscribe = find.byKey(const ValueKey('play-subscribe'));
      expect(subscribe, findsOneWidget);
      expect(tester.widget<DcoButton>(subscribe).onPressed, isNull);
      expect(find.textContaining('unavailable in demo mode'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-free')).hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('plan-free')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a paid plan'), findsOneWidget);
      await tester.tap(find.text('Choose a paid plan'));
      await tester.pumpAndSettle();
      expect(find.text('Subscribe with Google Play'), findsOneWidget);
      expect(tester.widget<DcoButton>(subscribe).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final lang in ['en', 'my']) {
    testWidgets(
      'Play checkout uses native prices and exposes restore/manage in $lang',
      (tester) async {
        await pumpPricing(tester, lang, play: true, scale: 1.3);
        final context = tester.element(find.byType(PricingScreen));
        final s = AppLocalizations.of(context)!;
        expect(find.text(s.playSubscribe), findsOneWidget);
        expect(find.text(s.playRestore), findsOneWidget);
        expect(find.text(s.playManage), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('featured-price')),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('featured-price')))
              .data,
          '\$2.99',
        );
        await tester.scrollUntilVisible(
          find.text(s.pricingAnnual),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(s.pricingAnnual));
        await tester.pumpAndSettle();
        expect(find.text(s.playTerms), findsOneWidget);
        expect(find.textContaining('MMK'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final lang in ['en', 'my']) {
    testWidgets(
      'compare plans and navigate to separate gift redemption in $lang',
      (tester) async {
        await pumpPricing(tester, lang);
        expect(find.byType(TextField), findsNothing);
        expect(find.byKey(const ValueKey('featured-price')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('plan-lite')));
        await tester.pumpAndSettle();
        expect(
          (tester.widget<Text>(
            find.byKey(const ValueKey('featured-price')),
          )).data,
          lang == 'en' ? '3,000' : '၃,၀၀၀',
        );
        // Selection is comparison only; the current account stays Free.
        expect(find.textContaining('· Free'), findsOneWidget);
        final annual = lang == 'en' ? 'Annual' : 'နှစ်စဉ်';
        await tester.scrollUntilVisible(
          find.text(annual),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(annual));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 1800));
        await tester.pumpAndSettle();
        expect(
          (tester.widget<Text>(
            find.byKey(const ValueKey('featured-price')),
          )).data,
          lang == 'en' ? '30,000' : '၃၀,၀၀၀',
        );
        final cta = lang == 'en'
            ? 'Redeem a gift code'
            : 'လက်ဆောင်ကုဒ် အသုံးပြုရန်';
        await tester.tap(find.text(cta));
        await tester.pumpAndSettle();
        expect(find.byType(GiftRedemptionScreen), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'INVALIDCODE');
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('gift-submit'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.text(
            lang == 'en'
                ? 'This code is invalid, expired, disabled, or fully redeemed.'
                : 'ဤကုဒ် မမှန်ကန်ပါ၊ သက်တမ်းကုန်ပါပြီ၊ ပိတ်ထားပါသည် သို့မဟုတ် အသုံးပြုခွင့် ပြည့်သွားပါပြီ။',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(GiftRedemptionScreen), findsNothing);
        expect(
          (tester.widget<Text>(
            find.byKey(const ValueKey('featured-price')),
          )).data,
          lang == 'en' ? '30,000' : '၃၀,၀၀၀',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('unverified owners get verification on the separate screen', (
    tester,
  ) async {
    await pumpPricing(tester, 'en', verified: false);
    await tester.tap(find.text('Redeem a gift code'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text('Verify your email before redeeming a gift.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text keeps plan selection and gift action usable', (
    tester,
  ) async {
    await pumpPricing(tester, 'my', scale: 1.6);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-free')).hitTestable(),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('plan-free')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('featured-price')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('featured-price')), findsOneWidget);
    await tester.tap(find.text('လက်ဆောင်ကုဒ် အသုံးပြုရန်'));
    await tester.pumpAndSettle();
    expect(find.byType(GiftRedemptionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

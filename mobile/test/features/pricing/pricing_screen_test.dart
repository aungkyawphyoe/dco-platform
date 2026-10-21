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

void main() {
  for (final lang in ['en', 'my']) {
    testWidgets(
      'pricing supports $lang on a narrow screen and shows redemption feedback',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pricingRepositoryProvider.overrideWithValue(TestPricing()),
              sessionControllerProvider.overrideWith(() => TestSession(true)),
              licenseControllerProvider.overrideWith(TestLicense.new),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                locale: Locale(lang),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  brightness: lang == 'en' ? Brightness.dark : Brightness.light,
                  extensions: [
                    lang == 'en'
                        ? DcoTokens.garageMinimalDark
                        : DcoTokens.garageMinimalLight,
                  ],
                ),
                home: const PricingScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'INVALIDCODE');
        await tester.pumpAndSettle();
        final label = lang == 'en' ? 'Redeem code' : 'ကုဒ်အသုံးပြုရန်';
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(
          find.text(
            lang == 'en'
                ? 'This code is invalid, expired, disabled, or fully redeemed.'
                : 'ဤကုဒ် မမှန်ကန်ပါ၊ သက်တမ်းကုန်ပါပြီ၊ ပိတ်ထားပါသည် သို့မဟုတ် အသုံးပြုခွင့် ပြည့်သွားပါပြီ။',
          ),
          findsOneWidget,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Standard'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Standard'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

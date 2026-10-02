import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/profile/presentation/widgets/license_flip_card.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: buildDcoTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets(
      'dispose without media does not force-create the flip controller',
      (tester) async {
    await tester.pumpWidget(
      host(const LicenseFlipCard(frontMediaId: null, backMediaId: null)),
    );
    await tester.pumpWidget(host(const SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('card with media flips front to back on tap', (tester) async {
    await tester.pumpWidget(
      host(
        const LicenseFlipCard(frontMediaId: 'front-id', backMediaId: 'back-id'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LicenseFlipCard));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

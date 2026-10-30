import 'dart:async';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/presentation/screens/units_formats_screen.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final driver in [false, true]) {
    testWidgets(
      'shows saved currency changes for ${driver ? "fleet" : "personal"} scope',
      (tester) async {
        final states = StreamController<Map<String, dynamic>?>();
        addTearDown(states.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              driverOrganizationIdProvider.overrideWithValue(
                driver ? 'org-1' : null,
              ),
              userPreferencesProvider.overrideWith(
                (ref) => Stream.value(UserPreferences.defaults),
              ),
              selectedCurrencyStateProvider.overrideWith(
                (ref) => states.stream,
              ),
            ],
            child: MaterialApp(
              theme: buildDcoTheme(Brightness.dark),
              home: const UnitsFormatsScreen(),
            ),
          ),
        );
        expect(find.text('Loading currency…'), findsOneWidget);
        for (final entry in {
          'USD': 'US Dollar (USD)',
          'THB': 'Thai Baht (THB)',
          'CNY': 'Chinese Yuan (CNY)',
          'MMK': 'Myanmar Kyat (MMK)',
        }.entries) {
          states.add({'currency': entry.key});
          await tester.pump();
          await tester.pump();
          expect(find.text(entry.value), findsOneWidget);
          if (entry.key != 'MMK')
            expect(find.text('Myanmar Kyat (MMK)'), findsNothing);
        }
        states.add({'currency': null});
        await tester.pump();
        await tester.pump();
        expect(find.text('Not selected'), findsOneWidget);
        states.add(null);
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Sync to load your selected currency'),
          findsOneWidget,
        );
        expect(
          find.textContaining(driver ? 'Fleet Admin' : 'during setup'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

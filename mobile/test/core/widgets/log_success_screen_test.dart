import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/presentation/screens/expense_success_screen.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/fuel/presentation/screens/fuel_log_success_screen.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final date = DateTime(2026, 11, 14);
  for (final locale in ['en', 'my']) {
    for (final brightness in Brightness.values) {
      for (final kind in ['refuel', 'charge', 'expense']) {
        testWidgets('$kind confirmation: $locale, $brightness, narrow screen', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final screen = kind == 'expense'
              ? ExpenseSuccessScreen(
                  expense: Expense(
                    id: 'expense',
                    vehicleId: 'vehicle',
                    category: ExpenseCategory.parking,
                    amount: 12.50,
                    currency: 'USD',
                    incurredOn: date,
                    updatedAt: date,
                    createdAt: date,
                    notes: 'Parking receipt',
                  ),
                )
              : FuelLogSuccessScreen(
                  log: FuelLog(
                    id: 'fuel',
                    userId: 'user',
                    vehicleId: 'vehicle',
                    kind: FuelLogKind.parse(kind),
                    fuelTypeId: 'type',
                    fuelTypeName: kind == 'charge' ? 'Electric' : 'Petrol',
                    unit: kind == 'charge' ? 'kWh' : 'L',
                    loggedOn: date,
                    amount: 20,
                    cost: 12.50,
                    currency: 'USD',
                    odometer: 100,
                    updatedAt: date,
                    createdAt: date,
                  ),
                );
          final router = GoRouter(
            initialLocation: '/success',
            routes: [
              GoRoute(path: '/success', builder: (_, _) => screen),
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, _) => const Scaffold(body: Text('Garage home')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [lengthUnitProvider.overrideWithValue(MileageUnit.km)],
              child: MaterialApp.router(
                theme: buildDcoTheme(brightness),
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final s = AppLocalizations.of(
            tester.element(find.byType(screen.runtimeType)),
          )!;
          expect(
            find.text(
              kind == 'expense'
                  ? s.expenseSuccessTitle
                  : kind == 'charge'
                  ? s.chargeSuccessTitle
                  : s.refuelSuccessTitle,
            ),
            findsOneWidget,
          );
          expect(find.text(s.logSuccessSubtitle), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text(MoneyFormat.labeled(12.50, 'USD')),
            150,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(s.registerSuccessBackHome));
          await tester.pumpAndSettle();
          expect(find.text('Garage home'), findsOneWidget);
          expect(router.canPop(), isFalse);
        });
      }
    }
  }
}

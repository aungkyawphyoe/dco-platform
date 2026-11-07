import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/features/dashboard/presentation/widgets/recent_activity_card.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/providers.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final date = DateTime(2026, 11, 7);
  final service = ServiceRecord(
    id: 'service',
    vehicleId: 'car',
    title: 'Oil change',
    servicedOn: date,
    odometer: 100,
    totalCost: 45,
    items: [],
    updatedAt: date,
    createdAt: date,
  );
  final fuel = FuelLog(
    id: 'fuel',
    userId: 'user',
    vehicleId: 'car',
    kind: FuelLogKind.refuel,
    fuelTypeId: 'premium',
    fuelTypeName: 'Premium',
    unit: 'L',
    loggedOn: date.add(const Duration(hours: 1)),
    amount: 30,
    cost: 60,
    updatedAt: date,
    createdAt: date,
    fillStatus: 'full',
  );
  final expenses = List.generate(
    12,
    (i) => Expense(
      id: 'expense$i',
      vehicleId: 'car',
      category: ExpenseCategory.parking,
      amount: 5,
      incurredOn: date.subtract(Duration(days: i + 1)),
      updatedAt: date,
      createdAt: date,
    ),
  );
  Future<void> pump(
    WidgetTester tester, {
    bool empty = false,
    bool error = false,
    bool standalone = false,
    Brightness brightness = Brightness.light,
    String language = 'en',
  }) async {
    tester.view.physicalSize = const Size(375, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: RecentActivityCard()),
          ),
        ),
        for (final path in [
          '/dashboard/fuel/fuel',
          '/maintenance/history/service',
          '/expenses/expense0',
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('Opened $path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceHistoryProvider.overrideWith(
            (ref) => error
                ? Stream.error(Exception('failed'))
                : Stream.value(empty ? [] : [service]),
          ),
          vehicleFuelLogsProvider.overrideWith(
            (ref) => Stream.value(empty ? [] : [fuel]),
          ),
          vehicleExpensesProvider.overrideWith(
            (ref) => Stream.value(
              empty
                  ? []
                  : [
                      for (final source in [
                        (
                          id: service.id,
                          category: ExpenseCategory.maintenance,
                          amount: service.totalCost,
                        ),
                        (
                          id: fuel.id,
                          category: ExpenseCategory.fuel,
                          amount: fuel.cost,
                        ),
                      ])
                        Expense(
                          id: source.id,
                          vehicleId: 'car',
                          category: source.category,
                          amount: source.amount,
                          incurredOn: date,
                          updatedAt: date,
                          createdAt: date,
                        ),
                      if (standalone)
                        Expense(
                          id: 'standalone',
                          vehicleId: 'car',
                          category: ExpenseCategory.maintenance,
                          notes: 'Separate car wash',
                          amount: service.totalCost,
                          incurredOn: date,
                          updatedAt: date,
                          createdAt: date,
                        ),
                      ...expenses,
                    ],
            ),
          ),
          currencyProvider.overrideWith((ref) => const AppCurrency('USD')),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildDcoTheme(brightness),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('combines, sorts and caps ten rows in one card', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('/expenses/service')), findsNothing);
    expect(find.byKey(const ValueKey('/expenses/fuel')), findsNothing);
    expect(find.byType(DcoCard), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(9));
    expect(find.byKey(const ValueKey('/expenses/expense7')), findsOneWidget);
    expect(find.byKey(const ValueKey('/expenses/expense8')), findsNothing);
    expect(
      tester.getTopLeft(find.text('Full tank - Premium')).dy,
      lessThan(tester.getTopLeft(find.text('Oil change')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Oil change')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('/expenses/expense0'))).dy,
      ),
    );
    expect(find.text(r'$45.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final route in [
    '/dashboard/fuel/fuel',
    '/maintenance/history/service',
    '/expenses/expense0',
  ]) {
    testWidgets('opens $route', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(ValueKey(route)));
      await tester.pumpAndSettle();
      expect(find.text('Opened $route'), findsOneWidget);
    });
  }
  testWidgets(
    'keeps standalone expenses with matching category, date and amount',
    (tester) async {
      await pump(tester, standalone: true);
      expect(find.text('Separate car wash'), findsOneWidget);
      expect(find.text('Oil change'), findsOneWidget);
      expect(find.byKey(const ValueKey('/expenses/service')), findsNothing);
      expect(find.byType(Divider), findsNWidgets(9));
    },
  );
  testWidgets('empty guidance', (tester) async {
    await pump(tester, empty: true);
    expect(find.text('No activity yet'), findsOneWidget);
  });
  testWidgets('failure offers retry', (tester) async {
    await pump(tester, error: true);
    expect(find.text('Could not load recent activity'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets('dark Burmese narrow layout with larger text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, brightness: Brightness.dark, language: 'my');
    expect(find.byType(Divider), findsNWidgets(9));
    expect(tester.takeException(), isNull);
  });
}

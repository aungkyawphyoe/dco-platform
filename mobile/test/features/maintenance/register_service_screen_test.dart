import 'dart:async';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/garage/access_provider.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/presentation/screens/register_service_screen.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/parts/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'suggested_items_scope_test.dart' as fixtures;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'cold preselection can add another service with the keyboard open',
    (tester) async {
      final car = fixtures.vehicle('car', 'user');
      final plan = StreamController<List<PlanItem>>();
      addTearDown(plan.close);
      PlanItem item(String id, String name) => PlanItem(
        id: id,
        vehicleId: 'car',
        name: name,
        enabled: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
            activeVehicleProvider.overrideWith((ref) => Stream.value(car)),
            vehicleAccessProvider(
              car,
            ).overrideWithValue(VehicleAccess.of(car, 'user', writable: true)),
            maintenancePlanProvider.overrideWith((ref) => plan.stream),
            maintenanceCatalogRefreshProvider.overrideWith((ref) async => true),
            suggestedItemsProvider((
              userId: 'user',
              vehicleId: 'car',
            )).overrideWith((ref) => Stream.value([])),
            suggestedItemsProvider((
              userId: 'user',
              vehicleId: '',
            )).overrideWith((ref) => Stream.value([])),
            vehiclePartsProvider.overrideWith((ref) => Stream.value([])),
            documentsForVehicleProvider(
              'car',
            ).overrideWith((ref) => Stream.value([])),
            lengthUnitProvider.overrideWithValue(MileageUnit.km),
            currencyProvider.overrideWithValue(const AppCurrency('MMK')),
          ],
          child: MaterialApp(
            theme: buildDcoTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RegisterServiceScreen(preselectedPlanItemId: 'wash'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      plan.add([item('wash', 'Car Wash'), item('mileage', 'Mileage Update')]);
      await tester.pumpAndSettle();
      final add = find.widgetWithText(OutlinedButton, 'add service');
      await tester.scrollUntilVisible(
        add,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Custom service');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.tap(find.text('Mileage Update').last);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Mileage Update'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        add,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.enterText(field, 'Tire check');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pump();
      await tester.tap(find.text('Add custom'));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tire check'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

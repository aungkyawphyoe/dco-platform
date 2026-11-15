import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/fuel/domain/repositories/fuel_repository.dart';
import 'package:dco_mobile/features/fuel/presentation/screens/fuel_log_form_screen.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/garage/access_provider.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import '../maintenance/suggested_items_scope_test.dart' as fixtures;

class FuelRepo extends Mock implements FuelRepository {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final kind in FuelLogKind.values) {
    for (final locale in ['en', 'my']) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '$kind $locale $brightness: stored selection, required mileage, battery',
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final car = fixtures.vehicle('car', 'user');
            final repo = FuelRepo();
            final type = FuelCatalogType(
              id: 'existing-id',
              userId: 'user',
              name: kind == FuelLogKind.charge
                  ? 'Electric (Fast)'
                  : '95 Octane gasoline (petrol)',
              kind: kind.catalogKind,
              unit: kind.catalogKind.defaultUnit,
              updatedAt: DateTime(2026),
              createdAt: DateTime(2026),
            );
            when(
              () => repo.ensureDefaultFuelTypes('user'),
            ).thenAnswer((_) async {});
            when(
              () => repo.watchFuelTypes('user', kind: kind.catalogKind),
            ).thenAnswer((_) => Stream.value([type]));
            final container = ProviderContainer(
              overrides: [
                currentUserIdProvider.overrideWithValue('user'),
                fuelRepositoryProvider.overrideWithValue(repo),
                activeVehicleProvider.overrideWith((ref) => Stream.value(car)),
                matchingFuelTypesProvider.overrideWithValue([type]),
                vehicleAccessProvider(car).overrideWithValue(
                  VehicleAccess.of(car, 'user', writable: true),
                ),
                currencyProvider.overrideWithValue(const AppCurrency('MMK')),
                lengthUnitProvider.overrideWithValue(MileageUnit.km),
                documentsForVehicleProvider(
                  'car',
                ).overrideWith((ref) => Stream.value([])),
              ],
            );
            addTearDown(container.dispose);
            // Preferences need no network or database in this form test.
            await container.read(activeVehicleProvider.future);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: buildDcoTheme(brightness),
                  locale: Locale(locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: FuelLogForm(kind: kind),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final s = AppLocalizations.of(
              tester.element(find.byType(FuelLogForm)),
            )!;
            expect(tester.widget<AppBar>(find.byType(AppBar)).actions, isNull);
            await tester.tap(find.byKey(const Key('fuel-log-type')));
            await tester.pumpAndSettle();
            expect(find.text(s.fuelLogFormAddFuelType), findsNothing);
            await tester.tap(find.widgetWithText(ListTile, type.name));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<DcoTextField>(find.byKey(const Key('fuel-log-type')))
                  .controller
                  .text,
              type.name,
            );
            await tester.tap(find.byKey(const Key('fuel-log-save')));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.byKey(const Key('fuel-log-odometer')),
              150,
              scrollable: find.byType(Scrollable).first,
            );
            final odometer = tester.widget<DcoTextField>(
              find.byKey(const Key('fuel-log-odometer')),
            );
            expect(odometer.errorText, s.vehicleMileageRequired);
            expect(odometer.helperText, isNotEmpty);
            if (kind == FuelLogKind.charge) {
              await tester.scrollUntilVisible(
                find.byKey(const Key('fuel-log-battery-level')),
                -150,
                scrollable: find.byType(Scrollable).first,
              );
              expect(find.text(s.fuelBatteryLevelError), findsOneWidget);
              final slider = find.byKey(const Key('fuel-log-battery-level'));
              tester.widget<RangeSlider>(slider).onChanged!(
                const RangeValues(33, 80),
              );
              await tester.pump();
              expect(find.text('33% → 80%'), findsOneWidget);
              expect(find.text(s.fuelBatteryLevelError), findsNothing);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}

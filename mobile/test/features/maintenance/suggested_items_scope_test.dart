import 'dart:async';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/suggested_plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/repositories/maintenance_catalog_repository.dart';
import 'package:dco_mobile/features/maintenance/presentation/screens/suggested_items_screen.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Vehicle vehicle(String id, String user) => Vehicle(
  id: id,
  userId: user,
  name: id,
  make: 'Toyota',
  model: 'Test',
  year: 2024,
  licensePlate: id,
  fuelType: FuelType.petrol,
  mileage: 0,
  mileageUnit: MileageUnit.km,
  archived: false,
  updatedAt: DateTime(2026),
  createdAt: DateTime(2026),
);
const suggestion = SuggestedPlanItem(
  catalogKey: 'oil',
  name: 'Oil change',
  fuelTypes: {FuelType.petrol},
  intervalDays: 365,
);
final user = StateProvider<String>((ref) => 'a');
final sync = StateProvider<SyncState>((ref) => SyncState.initial);

class Catalog extends MaintenanceCatalogRepository {
  final calls = <String>[];
  bool fail = true;
  @override
  Future<void> fetchAndCache(String vehicleId) async {
    calls.add(vehicleId);
    if (fail) throw StateError('Vehicle not uploaded yet');
  }

  @override
  Stream<List<SuggestedPlanItem>?> watchForVehicle(String vehicleId) =>
      Stream.value(null);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  test(
    'successful sync retries a failed catalog fetch for a newly created vehicle',
    () async {
      final catalog = Catalog();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
          activeVehicleProvider.overrideWith(
            (ref) => Stream.value(vehicle('new-car', ref.watch(user))),
          ),
          driverOrganizationIdProvider.overrideWithValue(null),
          maintenanceCatalogRepositoryProvider.overrideWithValue(catalog),
          syncStatusProvider.overrideWith(
            (ref) => Stream.value(ref.watch(sync)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        maintenanceCatalogRefreshProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(activeVehicleProvider.future);
      await container.read(syncStatusProvider.future);
      await container.pump();
      expect(
        await container.read(maintenanceCatalogRefreshProvider.future),
        false,
      );
      final before = catalog.calls.length;
      catalog.fail = false;
      container.read(sync.notifier).state = SyncState(
        phase: SyncPhase.idle,
        lastSyncedAt: DateTime(2026, 11, 1),
      );
      await container.read(syncStatusProvider.future);
      await container.pump();
      await container.read(maintenanceCatalogRefreshProvider.future);
      expect(catalog.calls.length, greaterThan(before));
      expect(catalog.calls.last, 'new-car');
    },
  );

  Future<void> pump(
    WidgetTester tester,
    List<SuggestedPlanItem>? suggestions, {
    Stream<List<PlanItem>>? secondPlan,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
          activeVehicleProvider.overrideWith((ref) {
            final id = ref.watch(user);
            return Stream.value(vehicle('car-$id', id));
          }),
          lengthUnitProvider.overrideWithValue(MileageUnit.km),
          maintenanceCatalogRefreshProvider.overrideWith((ref) async => true),
          suggestedItemsProvider.overrideWith(
            (ref, scope) => Stream.value(suggestions),
          ),
          suggestedVehiclePlanProvider.overrideWith((ref, scope) {
            if (scope.userId == 'a') {
              return Stream.value([
                PlanItem(
                  id: 'plan-a',
                  vehicleId: 'car-a',
                  name: 'Oil change',
                  catalogKey: 'oil',
                  enabled: true,
                  updatedAt: DateTime(2026),
                  createdAt: DateTime(2026),
                ),
              ]);
            }
            return secondPlan ?? Stream.value([]);
          }),
        ],
        child: MaterialApp(
          theme: buildDcoTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SuggestedItemsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'completed account A cannot hide suggestions for new account B while its plan loads',
    (tester) async {
      final bPlan = StreamController<List<PlanItem>>.broadcast();
      addTearDown(bPlan.close);
      await pump(tester, [suggestion], secondPlan: bPlan.stream);
      final context = tester.element(find.byType(SuggestedItemsScreen));
      final s = AppLocalizations.of(context)!;
      expect(find.text(s.suggestedItemsAllAdded), findsOneWidget);
      final container = ProviderScope.containerOf(context);
      container.read(user.notifier).state = 'b';
      await tester.pump();
      await tester.pump();
      expect(find.text(s.suggestedItemsAllAdded), findsNothing);
      bPlan.add([]);
      await tester.pumpAndSettle();
      expect(find.text('Oil change'), findsOneWidget);
      expect(find.text(s.suggestedItemsAllAdded), findsNothing);
    },
  );

  for (final cached in [false, true]) {
    testWidgets(
      'empty catalog cached=$cached is not all-added and includes retry',
      (tester) async {
        await pump(tester, cached ? [] : null);
        final s = AppLocalizations.of(
          tester.element(find.byType(SuggestedItemsScreen)),
        )!;
        expect(find.text(s.suggestedItemsAllAdded), findsNothing);
        expect(
          find.text(
            cached
                ? s.suggestedItemsNoneAvailable
                : s.suggestedItemsUnavailable,
          ),
          findsOneWidget,
        );
        expect(find.text(s.retry), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );
  }
}

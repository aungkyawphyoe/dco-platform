import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/dashboard/presentation/widgets/dashboard_vehicle_empty_state.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final car = Vehicle(
    id: 'car',
    userId: 'user',
    name: 'Car',
    make: 'Toyota',
    model: 'Corolla',
    year: 2024,
    licensePlate: 'ABC',
    fuelType: FuelType.petrol,
    mileage: 100,
    mileageUnit: MileageUnit.km,
    archived: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  Future<void> pump(
    WidgetTester tester, {
    List<Vehicle> vehicles = const [],
    bool loaded = false,
    bool failed = false,
    bool driver = false,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: DashboardVehicleEmptyState()),
        ),
        GoRoute(
          path: '/dashboard/garage',
          builder: (_, _) => const Scaffold(body: Text('Garage opened')),
        ),
        GoRoute(
          path: '/dashboard/garage/new',
          builder: (_, _) => const Scaffold(body: Text('Create opened')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageVehiclesProvider.overrideWith((ref) => Stream.value(vehicles)),
          garageLoadedProvider.overrideWith((ref) => Stream.value(loaded)),
          syncStatusProvider.overrideWith(
            (ref) => Stream.value(
              SyncState(
                phase: failed
                    ? SyncPhase.error
                    : loaded
                    ? SyncPhase.idle
                    : SyncPhase.syncing,
              ),
            ),
          ),
          driverOrganizationIdProvider.overrideWithValue(driver ? 'org' : null),
        ],
        child: MaterialApp.router(
          theme: buildDcoTheme(Brightness.light),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'first login waits for account sync rather than inviting registration',
    (tester) async {
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Register a vehicle'), findsNothing);
    },
  );
  testWidgets('existing vehicles without an active selection lead to Garage', (
    tester,
  ) async {
    await pump(tester, vehicles: [car]);
    expect(find.text('Choose an active vehicle'), findsOneWidget);
    expect(find.text('Register a vehicle'), findsNothing);
    await tester.tap(find.byKey(const Key('activate-vehicle-cta')));
    await tester.pumpAndSettle();
    expect(find.text('Garage opened'), findsOneWidget);
  });
  testWidgets('failed first sync offers Retry, never registration', (
    tester,
  ) async {
    await pump(tester, failed: true);
    expect(find.byKey(const Key('retry-vehicles-cta')), findsOneWidget);
    expect(find.text('Register a vehicle'), findsNothing);
  });
  testWidgets(
    'confirmed empty account offers vehicle creation even offline later',
    (tester) async {
      await pump(tester, loaded: true, failed: true);
      expect(find.byKey(const Key('register-vehicle-cta')), findsOneWidget);
      await tester.tap(find.byKey(const Key('register-vehicle-cta')));
      await tester.pumpAndSettle();
      expect(find.text('Create opened'), findsOneWidget);
    },
  );
  testWidgets('driver with a confirmed empty garage sees assignment guidance', (
    tester,
  ) async {
    await pump(tester, loaded: true, driver: true);
    expect(find.text('No assigned vehicle'), findsOneWidget);
    expect(find.byKey(const Key('register-vehicle-cta')), findsNothing);
  });
}

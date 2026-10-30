import 'dart:async';
import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/gating/feature_gate.dart';
import 'package:dco_mobile/core/gating/license_models.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/core/router/garage_overview_screen.dart';
import 'package:dco_mobile/features/vehicle_sharing/providers.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/entities/vehicle_share.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Entry-point hiding for the vehicle cap (`architecture/feature-gating.md`
/// §8.3, decision 2 principle: hide entry points, honest offline UX).
/// The server re-checks every create — these tests pin the local UX.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // One in-memory DB for the whole file — one QueryExecutor, one instance.
  final db = AppDatabase(NativeDatabase.memory());
  tearDownAll(db.close);

  final vehicle = Vehicle(
    id: 'v1',
    userId: 'u1',
    name: 'Daily',
    make: 'Toyota',
    model: 'Corolla',
    year: 2020,
    licensePlate: 'XY-1',
    fuelType: FuelType.petrol,
    mileage: 1000,
    mileageUnit: MileageUnit.km,
    archived: false,
    updatedAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  FeatureGateSnapshot freeGate({int vehicleCount = 0}) => FeatureGateSnapshot(
    claims: EntitlementClaims.free,
    vehicleCount: vehicleCount,
    activeShareCount: 0,
  );

  Future<void> pumpGarage(
    WidgetTester tester, {
    required FeatureGateSnapshot? gate,
    required List<Vehicle> vehicles,
    bool driver = false,
    Stream<List<Vehicle>>? vehicleStream,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.dark,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:8080/v1',
              jwtOwnerAud: 'dco-owner',
              mockAuth: true,
              analyticsEnabled: false,
            ),
          ),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          appDatabaseProvider.overrideWithValue(db),
          sharedVehiclesProvider.overrideWith(
            (ref) async => vehicles
                .where((v) => v.source == VehicleSource.shared)
                .map(
                  (v) => SharedVehicle.fromJson({
                    ...v.toWriteJson(),
                    'user_id': v.userId,
                    'owner': {'id': v.userId, 'display_name': 'Vehicle owner'},
                  }),
                )
                .toList(),
          ),
          garageVehiclesProvider.overrideWith(
            (ref) => vehicleStream ?? Stream.value(vehicles),
          ),
          activeVehicleProvider.overrideWith(
            (ref) => Stream<Vehicle?>.value(
              vehicles.isEmpty ? null : vehicles.first,
            ),
          ),
          featureGateProvider.overrideWithValue(gate),
          driverOrganizationIdProvider.overrideWithValue(driver ? 'org' : null),
        ],
        child: MaterialApp(
          theme: buildDcoTheme(brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const GarageOverviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('at the free cap: the "+" entry is hidden and the add card '
      'shows the limit copy instead of a subtitle', (tester) async {
    await pumpGarage(
      tester,
      gate: freeGate(vehicleCount: 1),
      vehicles: [vehicle],
    );

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.textContaining('allows 1 vehicles'), findsOneWidget);
    expect(find.textContaining('XY-1'), findsOneWidget); // rows stay visible
  });

  testWidgets('under the cap: the "+" entry is shown', (tester) async {
    await pumpGarage(tester, gate: freeGate(), vehicles: const []);

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('No vehicles yet'), findsOneWidget);
  });

  testWidgets('hydrating (null) gate keeps the entry — deny-by-default '
      'lives at the form save, not the button', (tester) async {
    await pumpGarage(tester, gate: null, vehicles: const []);

    expect(find.byIcon(Icons.add), findsOneWidget);
  });
  testWidgets(
    'Driver garage hides creation and sharing while the license loads',
    (tester) async {
      await pumpGarage(tester, gate: null, vehicles: [vehicle], driver: true);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
      expect(find.byIcon(Icons.people_outline), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  final shared = Vehicle(
    id: 'shared-1',
    userId: 'owner',
    name: 'Borrowed car',
    make: 'Toyota',
    model: 'Yaris',
    year: 2021,
    licensePlate: 'SH-1',
    fuelType: FuelType.petrol,
    mileage: 100,
    mileageUnit: MileageUnit.km,
    archived: false,
    updatedAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    source: VehicleSource.shared,
  );

  for (final locale in [const Locale('en'), const Locale('my')]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('Owned/Shared tabs separate vehicles: $locale $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpGarage(
          tester,
          gate: freeGate(),
          vehicles: [vehicle, shared],
          locale: locale,
          brightness: brightness,
        );
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text('XY-1'), findsOneWidget);
        expect(find.text('SH-1'), findsNothing);
        await tester.tap(find.byType(Tab).last);
        await tester.pumpAndSettle();
        expect(find.text('SH-1'), findsOneWidget);
        expect(find.text('XY-1'), findsNothing);
        expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
        expect(find.byIcon(Icons.add), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('shared-only garage keeps Owned empty and Shared accessible', (
    tester,
  ) async {
    final stream = StreamController<List<Vehicle>>()..add([shared]);
    addTearDown(stream.close);
    await pumpGarage(
      tester,
      gate: freeGate(),
      vehicles: [shared],
      vehicleStream: stream.stream,
    );
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('No vehicles yet'), findsOneWidget);
    await tester.tap(find.text('Shared'));
    await tester.pumpAndSettle();
    expect(find.text('SH-1'), findsOneWidget);
    // Losing the last share returns to the ordinary garage without tabs.
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
  });
  testWidgets('drivers never get ownership tabs for assigned vehicles', (
    tester,
  ) async {
    await pumpGarage(tester, gate: null, vehicles: [shared], driver: true);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('SH-1'), findsOneWidget);
  });
}

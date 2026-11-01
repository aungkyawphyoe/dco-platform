import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/onboarding/tour_targets.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/onboarding/data/repositories/tour_state_repository_impl.dart';
import 'package:dco_mobile/features/onboarding/domain/entities/tour_progress.dart';
import 'package:dco_mobile/features/onboarding/presentation/tour_controller.dart';
import 'package:dco_mobile/features/onboarding/presentation/widgets/tour_overlay.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _testUserIdProvider = StateProvider<String?>((ref) => 'u1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpOverlay(
    WidgetTester tester, {
    int branch = 0,
    Widget? background,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith(
            (ref) => ref.watch(_testUserIdProvider),
          ),
          activeVehicleProvider.overrideWith((ref) => Stream.value(null)),
          driverOrganizationIdProvider.overrideWithValue(null),
          alwaysOfferTourProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: buildDcoTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                ?background,
                TourOverlay(currentBranch: branch),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations localizations(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(TourOverlay)))!;

  Future<TourProgress> savedProgress() =>
      TourStateRepositoryImpl(db).load('u1');

  testWidgets('offers the tour once and Not now persists dismissal', (
    tester,
  ) async {
    await pumpOverlay(tester);
    final s = localizations(tester);

    expect(find.text(s.tourOfferTitle), findsOneWidget);
    expect(find.text(s.tourShowMe), findsOneWidget);
    expect(find.text(s.tourNotNow), findsOneWidget);

    await tester.tap(find.text(s.tourNotNow));
    await tester.pumpAndSettle();

    expect(find.text(s.tourOfferTitle), findsNothing);
    expect((await savedProgress()).status, TourStatus.dismissed);
  });

  testWidgets('tour advances, goes back, and skips with persisted dismissal', (
    tester,
  ) async {
    await pumpOverlay(tester);
    final s = localizations(tester);

    await tester.tap(find.text(s.tourShowMe));
    await tester.pumpAndSettle();

    expect(find.text(s.tourStepOf(1, 4)), findsOneWidget);
    expect(find.text(s.tourVehicleTitle), findsOneWidget);
    expect(find.text(s.tourBack), findsNothing);

    await tester.tap(find.text(s.tourNext));
    await tester.pumpAndSettle();
    expect(find.text(s.tourStepOf(2, 4)), findsOneWidget);
    expect(find.text(s.tourMaintenanceTitle), findsOneWidget);

    await tester.tap(find.text(s.tourBack));
    await tester.pumpAndSettle();
    expect(find.text(s.tourStepOf(1, 4)), findsOneWidget);

    await tester.tap(find.text(s.tourSkip));
    await tester.pumpAndSettle();
    expect(find.text(s.tourStepOf(1, 4)), findsNothing);
    expect((await savedProgress()).status, TourStatus.dismissed);
  });

  testWidgets('finishing the last step records completion', (tester) async {
    await pumpOverlay(tester);
    final s = localizations(tester);

    await tester.tap(find.text(s.tourShowMe));
    await tester.pumpAndSettle();

    for (var step = 1; step < 4; step++) {
      await tester.tap(find.text(s.tourNext));
      await tester.pumpAndSettle();
    }
    expect(find.text(s.tourStepOf(4, 4)), findsOneWidget);
    expect(find.text(s.tourDone), findsOneWidget);

    await tester.tap(find.text(s.tourDone));
    await tester.pumpAndSettle();

    expect(find.text(s.tourStepOf(4, 4)), findsNothing);
    expect((await savedProgress()).status, TourStatus.completed);
  });

  testWidgets('completed accounts can replay explicitly', (tester) async {
    await TourStateRepositoryImpl(db).save(
      'u1',
      const TourProgress(version: kTourVersion, status: TourStatus.completed),
    );
    await pumpOverlay(tester);
    final s = localizations(tester);

    expect(find.text(s.tourOfferTitle), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TourOverlay)),
    );
    container.read(tourControllerProvider.notifier).start(tourStepsFor());
    await tester.pumpAndSettle();

    expect(find.text(s.tourStepOf(1, 4)), findsOneWidget);
  });

  testWidgets('does not offer the tour outside the Garage tab', (tester) async {
    await pumpOverlay(tester, branch: 2);
    final s = localizations(tester);

    expect(find.text(s.tourOfferTitle), findsNothing);
    expect((await savedProgress()).status, TourStatus.notSeen);
  });

  testWidgets('switching accounts gets that account its own offer', (
    tester,
  ) async {
    await TourStateRepositoryImpl(db).save(
      'u1',
      const TourProgress(version: kTourVersion, status: TourStatus.completed),
    );
    await pumpOverlay(tester);
    final s = localizations(tester);

    expect(find.text(s.tourOfferTitle), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TourOverlay)),
    );
    container.read(_testUserIdProvider.notifier).state = 'u2';
    await tester.pumpAndSettle();

    expect(find.text(s.tourOfferTitle), findsOneWidget);
  });

  testWidgets('the offer never blocks the screen behind it', (tester) async {
    var tapped = false;
    await pumpOverlay(
      tester,
      background: Center(
        child: TextButton(
          onPressed: () => tapped = true,
          child: const Text('Primary action'),
        ),
      ),
    );
    final s = localizations(tester);

    expect(find.text(s.tourOfferTitle), findsOneWidget);

    await tester.tap(find.text('Primary action'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue, reason: 'the offer card must not absorb the screen');
    expect(find.text(s.tourOfferTitle), findsOneWidget);
  });

  testWidgets('anchors register their target and release it on dispose', (
    tester,
  ) async {
    final registry = TourTargetRegistry();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tourTargetRegistryProvider.overrideWithValue(registry)],
        child: const MaterialApp(
          home: TourAnchor(
            target: TourTarget.expenses,
            child: Text('Expenses target'),
          ),
        ),
      ),
    );

    expect(registry.keyFor(TourTarget.expenses), isNotNull);

    await tester.pumpWidget(const SizedBox());

    expect(
      registry.keyFor(TourTarget.expenses),
      isNull,
      reason: 'a torn-down screen must not leave a stale anchor',
    );
  });
}

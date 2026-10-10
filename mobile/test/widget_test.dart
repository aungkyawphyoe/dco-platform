import 'package:dco_mobile/app.dart';
import 'package:dco_mobile/core/config/app_config.dart';
import 'package:dco_mobile/core/gating/license_store.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/notifications/local_notification_client.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/app_router.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/notifications/domain/entities/notification.dart';
import 'package:dco_mobile/features/notifications/presentation/screens/notification_feed_screen.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<AppDatabase> pumpSignedInApp(WidgetTester tester) async {
    final database = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:8080/v1',
              jwtOwnerAud: 'dco-owner',
              mockAuth: true,
            ),
          ),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          licenseStoreProvider.overrideWithValue(MemoryLicenseStore()),
          licenseKeyringProvider.overrideWith((ref) async => const []),
          appDatabaseProvider.overrideWithValue(database),
          localNotificationClientProvider.overrideWithValue(
            NoopLocalNotificationClient(),
          ),
          localeProvider.overrideWithValue(const Locale('en')),
        ],
        child: const DcoApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('A home for your car'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-sign-in')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'owner@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password12');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    return database;
  }

  testWidgets(
    'failed sign-in retains the form and displays localized feedback',
    (tester) async {
      final database = await pumpSignedInApp(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcoApp)),
      );
      await container.read(sessionControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('welcome-sign-in')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'owner@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(
        container
            .read(goRouterProvider)
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        AppRoutes.login,
      );
      expect(
        find.text('Your email, username, or password is incorrect.'),
        findsWidgets,
      );
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      await database.close();
    },
  );

  testWidgets('welcome to dashboard via mock sign in', (tester) async {
    final database = await pumpSignedInApp(tester);

    expect(find.text('Register a vehicle'), findsWidgets);

    await tester.tap(find.byKey(const Key('register-vehicle-cta')));
    await tester.pumpAndSettle();

    Future<void> fill(String key, String value) async {
      final field = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.enterText(field, value);
    }

    await fill('vehicle-name', 'Daily Driver');
    await fill('vehicle-year', '2022');
    await fill('vehicle-make', 'Toyota');
    await fill('vehicle-model', 'Camry');
    await fill('vehicle-plate', 'ABC123');
    await fill('vehicle-mileage', '45230');
    await tester.ensureVisible(find.text('Petrol'));
    await tester.tap(find.text('Petrol'));
    await tester.ensureVisible(find.byKey(const Key('vehicle-save')));
    await tester.tap(find.byKey(const Key('vehicle-save')));
    await tester.pumpAndSettle();

    expect(find.text('Maintenance Plan'), findsOneWidget);
    expect(find.text('No plan items yet'), findsNothing);
    expect(find.text('Mileage Update'), findsOneWidget);
    expect(find.text('Routine'), findsOneWidget);
    expect(find.byKey(const Key('maintenance-plan-done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('maintenance-plan-done')));
    await tester.pumpAndSettle();

    expect(find.text('My Garage'), findsOneWidget);
    expect(find.text('Daily Driver'), findsWidgets);
    expect(find.textContaining('Toyota Camry'), findsOneWidget);

    await database.delete(database.planItemRecords).go();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DcoApp)),
    );
    container.read(goRouterProvider).push(AppRoutes.maintenancePlan);
    await tester.pumpAndSettle();

    expect(find.text('No plan items yet'), findsNothing);
    expect(find.text('Mileage Update'), findsOneWidget);
    expect(find.text('Routine'), findsOneWidget);
    expect(find.byKey(const Key('maintenance-plan-done')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await database.close();
  });

  testWidgets('notification feed shows source badge and swipe actions', (
    tester,
  ) async {
    final database = await pumpSignedInApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DcoApp)),
    );

    final userId = container
        .read(sessionControllerProvider)
        .valueOrNull!
        .user
        .id;
    final vehicle = await container
        .read(vehicleRepositoryProvider)
        .add(
          userId: userId,
          draft: const VehicleDraft(
            name: 'Weekend Car',
            nickname: 'Daily Car',
            make: 'Toyota',
            model: 'Camry',
            year: 2022,
            licensePlate: 'XYZ789',
            fuelType: FuelType.petrol,
            mileage: 12000,
          ),
        );

    await container
        .read(notificationRepositoryProvider)
        .recordDue(
          userId: userId,
          vehicleId: vehicle.id,
          planItemId: 'plan-1',
          cycleKey: 'plan-1::cycle-1',
          title: 'Oil change due',
          body: 'Due in 30 days',
          dueReason: NotificationDueReason.date,
        );

    container.read(goRouterProvider).push(AppRoutes.notifications);
    await tester.pumpAndSettle();

    final feed = find.byType(NotificationFeedScreen);
    final feedTile = find.descendant(of: feed, matching: find.byType(ListTile));

    expect(
      find.descendant(of: feed, matching: find.text('Oil change due')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: feed, matching: find.text('Daily Car')),
      findsOneWidget,
    );

    final dxBefore = tester.getTopLeft(feedTile).dx;
    await tester.drag(feedTile, const Offset(-400, 0));
    await tester.pumpAndSettle();
    final dxAfter = tester.getTopLeft(feedTile).dx;
    expect(dxAfter, lessThan(dxBefore - 40));

    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: feed, matching: find.text('Restore')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await database.close();
  });
}

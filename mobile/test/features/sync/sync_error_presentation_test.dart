import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dco_mobile/app.dart';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/gating/license_models.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/app_router.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/presentation/screens/maintenance_success_screen.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/notifications/presentation/reminder_sync_controller.dart';
import 'package:dco_mobile/features/pricing/billing/providers.dart';
import 'package:dco_mobile/features/pricing/billing/play_billing_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/sync/presentation/screens/sync_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class _Session extends SessionController {
  @override
  Future<Session?> build() async => null;
}

class _License extends LicenseController {
  @override
  Future<EntitlementClaims> build() async => EntitlementClaims.free;
  @override
  Future<void> refreshIfStale({bool force = false}) async {}
}

class _Database extends Mock implements AppDatabase {}

class _Reminders extends Mock implements ReminderSyncController {}

class _Sync extends Mock implements SyncEngine {
  int retries = 0;
  @override
  Future<void> syncNow({bool force = false}) async {
    if (force) retries++;
  }
}

void main() {
  testWidgets(
    'background errors leave local success usable; Sync owns errors and retry',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final db = _Database();
      final states = StreamController<SyncState>();
      final engine = _Sync();
      final record = ServiceRecord(
        id: 'saved',
        vehicleId: 'car',
        title: 'Oil change',
        servicedOn: DateTime(2026),
        odometer: 100,
        totalCost: 8000,
        items: const [],
        updatedAt: DateTime(2026),
        createdAt: DateTime(2026),
      );
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MaintenanceSuccessScreen(record: record),
          ),
          GoRoute(path: '/sync', builder: (_, _) => const SyncStatusScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goRouterProvider.overrideWithValue(router),
            currentUserIdProvider.overrideWithValue(null),
            driverOrganizationIdProvider.overrideWithValue(null),
            sessionControllerProvider.overrideWith(_Session.new),
            licenseControllerProvider.overrideWith(_License.new),
            featureGateProvider.overrideWithValue(null),
            reminderSyncControllerProvider.overrideWithValue(_Reminders()),
            maintenanceCatalogRefreshProvider.overrideWith((ref) async => true),
            playBillingProvider.overrideWith(
              (ref) => PlayBillingController(
                store: null,
                backend: null,
                refreshEntitlements: () async => false,
                isCurrentAccount: () => true,
              ),
            ),
            connectivityProvider.overrideWith(
              (ref) => Stream.value([ConnectivityResult.none]),
            ),
            syncStatusProvider.overrideWith((ref) => states.stream),
            syncEngineProvider.overrideWithValue(engine),
            autoSyncProvider.overrideWith((ref) => AutoSyncNotifier(db, null)),
            pendingOutboxCountProvider.overrideWith((ref) async => 1),
            parkedOutboxCountProvider.overrideWith((ref) async => 0),
            organizationReviewsProvider.overrideWith((ref) => Stream.value([])),
            localeProvider.overrideWithValue(const Locale('en')),
            themeModeProvider.overrideWithValue(AppThemeMode.dark),
            userPreferencesProvider.overrideWith(
              (ref) => Stream.value(UserPreferences.defaults),
            ),
            currencyProvider.overrideWithValue(AppCurrency.mmk),
          ],
          child: const DcoApp(),
        ),
      );
      await tester.pumpAndSettle();
      for (final code in ['network', 'server', 'LIMIT_EXCEEDED', 'unknown']) {
        states.add(SyncState(phase: SyncPhase.error, errorCode: code));
        await tester.pumpAndSettle();
        expect(find.text('Service Logged!'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Could not sync'), findsNothing);
      }
      router.push('/sync');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-error-alert')), findsOneWidget);
      expect(find.text('Could not sync'), findsWidgets);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(engine.retries, 1);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Service Logged!'), findsOneWidget);
      expect(find.text('Could not sync'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await states.close();
      await tester.pump();

    },
  );
}

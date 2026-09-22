import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/dco_theme.dart';
import 'core/widgets/dco_error_dialog.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/notifications/presentation/reminder_sync_controller.dart';
import 'features/settings/providers.dart';
import 'generated/app_localizations.dart';

bool _isOnline(List<ConnectivityResult>? results) {
  if (results == null || results.isEmpty) return true;
  return results.any((result) => result != ConnectivityResult.none);
}

class DcoApp extends ConsumerStatefulWidget {
  const DcoApp({super.key});

  @override
  ConsumerState<DcoApp> createState() => _DcoAppState();
}

class _DcoAppState extends ConsumerState<DcoApp> {
  ({String message, DateTime at})? _lastSyncDialog;

  void _onSyncStatus(AsyncValue<SyncState> status) {
    final state = status.valueOrNull;
    if (state == null || !state.hasError) return;

    final message = state.message ?? 'Your changes will retry automatically.';
    final last = _lastSyncDialog;
    final cooldown = const Duration(minutes: 1);
    final alreadyShown =
        last != null && last.message == message && DateTime.now().difference(last.at) < cooldown;
    if (alreadyShown) return;
    _lastSyncDialog = (message: message, at: DateTime.now());

    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null || !mounted) return;
    unawaited(
      showDcoErrorDialog(
        navigatorContext,
        title: 'Sync failed',
        message: message,
        actionLabel: 'Retry',
        onAction: () => ref.read(syncEngineProvider).syncNow(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    ref.watch(reminderSyncControllerProvider);

    ref.listen(sessionControllerProvider, (previous, next) {
      final userId = next.valueOrNull?.user.id;
      final previousUserId = previous?.valueOrNull?.user.id;
      if (userId != null && userId != previousUserId) {
        ref.read(syncEngineProvider).syncNow();
        ref.read(profileRepositoryProvider).flushPendingActiveVehicle(userId);
        // Fetch maintenance catalog after login
        final activeVehicleId = next.valueOrNull?.user.activeVehicleId;
        if (activeVehicleId != null) {
          ref.read(maintenanceCatalogRepositoryProvider).fetchAndCache(activeVehicleId);
        }
      }
    });

    ref.listen(connectivityProvider, (previous, next) {
      final regained = !_isOnline(previous?.valueOrNull) && _isOnline(next.valueOrNull);
      if (regained && ref.read(autoSyncProvider)) {
        ref.read(syncEngineProvider).requestSync();
      }
    });

    ref.listen(syncStatusProvider, (_, next) => _onSyncStatus(next));

    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      key: ValueKey(locale.languageCode),
      title: 'DCO',
      debugShowCheckedModeBanner: false,
      theme: buildDcoTheme(),
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

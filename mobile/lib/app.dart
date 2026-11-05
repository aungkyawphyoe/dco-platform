import 'core/storage/account_lifecycle.dart';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/gating/providers.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/dco_theme.dart';
import 'core/widgets/dco_system_ui.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/maintenance/providers.dart';
import 'features/fleet/providers.dart';
import 'features/notifications/presentation/reminder_sync_controller.dart';
import 'features/pricing/billing/providers.dart';
import 'features/settings/domain/entities/user_preferences.dart';
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

class _DcoAppState extends ConsumerState<DcoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold-start license refresh behind the cached gate (decision 14).
    unawaited(_refreshLicenseIfStale());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLicenseIfStale());
      unawaited(ref.read(playBillingProvider.notifier).reload());
    }
  }

  /// Foreground trigger for §5.3 staleness (>24h old or <48h to expiry).
  /// Best-effort: the cached license already gates the UI.
  Future<void> _refreshLicenseIfStale() async {
    try {
      await ref.read(licenseControllerProvider.future);
      if (!mounted) return;
      await ref.read(licenseControllerProvider.notifier).refreshIfStale();
    } catch (_) {
      // Offline or unauthenticated — cached/Free claims stand.
    }
  }

  void _onSyncStatus(AsyncValue<SyncState> status) {
    if (ref.read(accountTransitionProvider)) return;
    final state = status.valueOrNull;
    if (state == null) return;
    // Background failures are presented only by Sync Status. A failed upload
    // must never interrupt a successful local save or another offline workflow.
    if (state.hasError) return;
    final userId = ref.read(currentUserIdProvider);
    if (state.lastSyncedAt != null &&
        userId != null &&
        ref.read(driverOrganizationIdProvider) == null) {
      unawaited(
        ref
            .read(profileRepositoryProvider)
            .flushPendingActiveVehicle(userId)
            .catchError((Object _) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transitioning = ref.watch(accountTransitionProvider);
    final router = ref.watch(goRouterProvider);
    ref.watch(reminderSyncControllerProvider);
    // Warm the feature gate (license + active counts) so the first
    // interactive check reads a settled snapshot instead of racing
    // hydration (§8.1).
    ref.watch(featureGateProvider);
    ref.watch(playBillingProvider);

    ref.listen(sessionControllerProvider, (previous, next) {
      final userId = next.valueOrNull?.user.id;
      final previousUserId = previous?.valueOrNull?.user.id;
      if (userId != null && userId != previousUserId) {
        ref.read(syncEngineProvider).syncNow();
        final personal =
            ref.read(appConfigProvider).mockAuth ||
            (ref.read(entitlementsProvider).valueOrNull != null &&
                ref.read(driverOrganizationIdProvider) == null);
        if (personal) {
          ref.read(profileRepositoryProvider).flushPendingActiveVehicle(userId);
        }
      }
    });

    ref.watch(maintenanceCatalogRefreshProvider);

    ref.listen(connectivityProvider, (previous, next) {
      final regained =
          !_isOnline(previous?.valueOrNull) && _isOnline(next.valueOrNull);
      if (regained) {
        unawaited(ref.read(playBillingProvider.notifier).reload());
      }
      if (regained && ref.read(autoSyncProvider)) {
        ref.read(syncEngineProvider).requestSync();
      }
    });

    ref.listen(syncStatusProvider, (_, next) => _onSyncStatus(next));

    final locale = ref.watch(localeProvider);
    final themeMode = switch (ref.watch(themeModeProvider)) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'AutoX',
      debugShowCheckedModeBanner: false,
      theme: buildDcoTheme(Brightness.light),
      darkTheme: buildDcoTheme(Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) => DcoSystemUi(
        themeMode: themeMode,
        child: Stack(
          children: [
            if (child != null)
              AbsorbPointer(absorbing: transitioning, child: child),
            if (transitioning)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.scrim.withValues(alpha: 0.6),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

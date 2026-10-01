import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/dco_theme.dart';
import 'core/theme/dco_tokens.dart';
import 'core/widgets/dco_error_dialog.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/notifications/presentation/reminder_sync_controller.dart';
import 'features/settings/domain/entities/user_preferences.dart';
import 'features/settings/providers.dart';
import 'generated/app_localizations.dart';

bool _isOnline(List<ConnectivityResult>? results) {
  if (results == null || results.isEmpty) return true;
  return results.any((result) => result != ConnectivityResult.none);
}

/// Keeps the OS status/navigation bars in sync with the active theme.
/// Lives inside `MaterialApp.router`'s builder so it reacts to live
/// `platformBrightness` changes while the theme mode is "system".
class _SystemUiOverlay extends StatelessWidget {
  const _SystemUiOverlay({required this.themeMode, required this.child});

  final ThemeMode themeMode;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = switch (themeMode) {
      ThemeMode.system => platformDark,
      ThemeMode.dark => true,
      ThemeMode.light => false,
    };
    final tokens = isDark
        ? DcoTokens.garageMinimalDark
        : DcoTokens.garageMinimalLight;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: tokens.background.nav,
        systemNavigationBarDividerColor: tokens.border.divider,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
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
    final themeMode = switch (ref.watch(themeModeProvider)) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      key: ValueKey(locale.languageCode),
      title: 'DCO',
      debugShowCheckedModeBanner: false,
      theme: buildDcoTheme(Brightness.light),
      darkTheme: buildDcoTheme(Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) =>
          _SystemUiOverlay(themeMode: themeMode, child: child),
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

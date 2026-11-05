import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// No active selection is different from a confirmed empty account.
class DashboardVehicleEmptyState extends ConsumerWidget {
  const DashboardVehicleEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final garage = ref.watch(garageVehiclesProvider);
    final loaded = ref.watch(garageLoadedProvider);
    final sync = ref.watch(syncStatusProvider);
    final hasVehicles = garage.asData?.value.isNotEmpty == true;
    if (hasVehicles) {
      return DcoEmptyState(
        title: s.dashboardChooseVehicleTitle,
        body: s.dashboardChooseVehicleBody,
        actionLabel: s.dashboardChooseVehicleAction,
        actionKey: const Key('activate-vehicle-cta'),
        onAction: () => context.push(AppRoutes.garage),
      );
    }
    if (garage.hasError || loaded.hasError) {
      return DcoEmptyState(
        title: s.dashboardVehicleLoadFailed,
        body: s.dashboardVehicleLoadRetryBody,
        actionLabel: s.retry,
        actionKey: const Key('retry-vehicles-cta'),
        onAction: () {
          ref.invalidate(garageVehiclesProvider);
          ref.invalidate(garageLoadedProvider);
          ref.read(syncEngineProvider).syncNow(force: true);
        },
      );
    }
    if (loaded.valueOrNull != true &&
        (sync.hasError || sync.valueOrNull?.hasError == true)) {
      return DcoEmptyState(
        title: s.dashboardVehiclesNotDownloaded,
        body: s.dashboardVehiclesNotDownloadedBody,
        actionLabel: s.syncStatusTitle,
        actionKey: const Key('open-sync-cta'),
        onAction: () => context.push(AppRoutes.sync),
      );
    }
    if (garage.asData == null ||
        loaded.valueOrNull != true ||
        sync.valueOrNull?.phase == SyncPhase.syncing) {
      return const Center(child: CircularProgressIndicator());
    }
    final driver = ref.watch(driverOrganizationIdProvider) != null;
    return DcoEmptyState(
      title: driver ? s.driverNoVehicleTitle : s.dashboardEmptyTitle,
      body: driver ? s.driverNoVehicleBody : s.dashboardEmptyBody,
      actionLabel: driver ? null : s.dashboardEmptyTitle,
      actionKey: const Key('register-vehicle-cta'),
      onAction: driver ? null : () => context.push(AppRoutes.vehicleNew),
    );
  }
}

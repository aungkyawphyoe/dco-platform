import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/driver_quick_actions.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Driver Garage tab: the assigned vehicle + Quick Actions (read-only).
///
/// Replaces the personal Dashboard. No personal garage, no mileage-log /
/// shift entry — maintenance comes from Quick Actions.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final myVehicleAsync = ref.watch(driverMyVehicleProvider);

    return Scaffold(
      body: SafeArea(
        child: myVehicleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => DcoEmptyState(
            title: s.driverNoVehicleTitle,
            body: s.driverNoVehicleBody,
          ),
          data: (myVehicle) {
            if (!myVehicle.hasAssignedVehicle) {
              return DcoEmptyState(
                title: s.driverNoVehicleTitle,
                body: s.driverNoVehicleBody,
              );
            }
            final vehicle = myVehicle.vehicle!;
            return ListView(
              padding: EdgeInsets.all(tokens.space.s4),
              children: [
                Card(
                  child: ListTile(
                    contentPadding: EdgeInsets.all(tokens.space.s3),
                    leading: Icon(
                      Icons.directions_car_outlined,
                      color: tokens.icon.inactive,
                      size: 32,
                    ),
                    title: Text(
                      vehicle.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      [
                        if (vehicle.licensePlate != null &&
                            vehicle.licensePlate!.isNotEmpty)
                          vehicle.licensePlate,
                        if (vehicle.vin != null && vehicle.vin!.isNotEmpty)
                          '${s.driverVin} ${vehicle.vin}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.text.caption,
                          ),
                    ),
                    trailing: StatusChip(
                      label: vehicle.status,
                      tone: vehicleStatusTone(vehicle.status),
                    ),
                  ),
                ),
                SectionHeader(
                  s.dashboardQuickActions,
                  action: TextButton(
                    onPressed: () => context.push(AppRoutes.driverReports),
                    child: Text(s.driverReportsTitle),
                  ),
                ),
                const DriverQuickActions(),
              ],
            );
          },
        ),
      ),
    );
  }
}

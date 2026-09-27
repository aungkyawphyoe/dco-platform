import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Driver mode Garage tab: the assigned vehicle and driver actions.
class DriverMyVehicleScreen extends ConsumerWidget {
  const DriverMyVehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final myVehicleAsync = ref.watch(driverMyVehicleProvider);

    return Scaffold(
      backgroundColor: tokens.background.primary,
      appBar: AppBar(title: Text(s.driverMyVehicleTab)),
      body: myVehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(driverMyVehicleProvider),
        ),
        data: (context2) {
          if (!context2.hasAssignedVehicle) {
            return DcoEmptyState(
              title: s.driverNoVehicleTitle,
              body: s.driverNoVehicleBody,
            );
          }
          final vehicle = context2.vehicle!;
          final orgName = context2.organization?.name;
          return ListView(
            padding: EdgeInsets.all(tokens.space.s3),
            children: [
              if (orgName != null && orgName.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.space.s2),
                  child: Text(
                    orgName,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: tokens.text.secondary),
                  ),
                ),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(tokens.space.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            color: tokens.icon.active,
                          ),
                          SizedBox(width: tokens.space.s2),
                          Expanded(
                            child: Text(
                              vehicle.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space.s3),
                      _Row(
                        label: s.driverPlate,
                        value: vehicle.licensePlate,
                      ),
                      _Row(
                        label: s.vehicleMakeLabel,
                        value:
                            '${vehicle.make} ${vehicle.model} ${vehicle.year}',
                      ),
                      _Row(
                        label: s.vehicleMileageLabel,
                        value: '${vehicle.mileage} ${vehicle.mileageUnit}',
                      ),
                      _Row(
                        label: s.vehicleFuelTypeLabel,
                        value: vehicle.fuelType,
                      ),
                      if (vehicle.vin != null && vehicle.vin!.isNotEmpty)
                        _Row(label: s.driverVin, value: vehicle.vin!),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space.s3),
              FleetTile(
                title: s.driverLogMileage,
                icon: Icons.speed_outlined,
                onTap: () => context.push(AppRoutes.driverShift),
              ),
              FleetTile(
                title: s.driverLogFuel,
                icon: Icons.local_gas_station_outlined,
                onTap: () => context.push(AppRoutes.driverFuelLog),
              ),
              FleetTile(
                title: s.fleetWoReportTitle,
                icon: Icons.report_problem_outlined,
                onTap: () => context.push(AppRoutes.driverReportIssue),
              ),
              FleetTile(
                title: s.driverInspectionStart,
                icon: Icons.checklist_outlined,
                onTap: () => context.push(AppRoutes.driverInspectionNew),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.caption),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared org vehicle list — used by the Fleet inventory tab and the Org
/// Management vehicles tab. Optional add / import entry points.
class FleetVehicleList extends ConsumerWidget {
  const FleetVehicleList({
    super.key,
    required this.orgId,
    this.onAdd,
    this.onImport,
  });

  final String orgId;
  final VoidCallback? onAdd;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehiclesAsync = ref.watch(orgVehiclesProvider(orgId));

    return vehiclesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => error is FleetAccessDenied
          ? DcoEmptyState(
              title: s.fleetOrgNotPermitted,
              body: s.fleetOrgNotPermittedBody,
            )
          : DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(orgVehiclesProvider(orgId)),
            ),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return DcoEmptyState(
            title: s.fleetInventoryEmpty,
            body: s.fleetInventoryEmptyBody,
            actionLabel: onAdd == null ? null : s.fleetInventoryAdd,
            onAction: onAdd,
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(tokens.space.s3),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Card(
              margin: EdgeInsets.only(bottom: tokens.space.s2),
              child: ListTile(
                leading: Icon(
                  Icons.directions_car,
                  color: tokens.icon.inactive,
                ),
                title: Text(vehicle.displayName),
                subtitle: Text(
                  [
                    vehicle.licensePlate,
                    '${vehicle.year} ${vehicle.make} ${vehicle.model}',
                  ].join(' · '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                ),
                trailing: StatusChip(
                  label: vehicle.status == 'transferred'
                      ? vehicleStatusLabel(s, vehicle.status)
                      : vehicle.assignedDriverId != null
                      ? fleetRoleLabel(s, 'org_driver')
                      : s.fleetInventoryUnassigned,
                  tone: vehicle.assignedDriverId != null
                      ? 'success'
                      : 'info',
                ),
                onTap: () =>
                    context.push(AppRoutes.fleetVehicleDetail(vehicle.id)),
              ),
            );
          },
        );
      },
    );
  }
}

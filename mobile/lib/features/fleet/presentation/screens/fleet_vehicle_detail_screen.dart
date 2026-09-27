import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Org vehicle detail: identity, lifecycle status transition, and the
/// showroom → buyer transfer entry point (admin / manager).
class FleetVehicleDetailScreen extends ConsumerWidget {
  const FleetVehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    String orgId,
    String template,
    String currentStatus,
  ) async {
    final s = AppLocalizations.of(context)!;
    final nextStatuses =
        lifecycleTransitions[template]?[currentStatus] ?? const <String>[];
    if (nextStatuses.isEmpty) return;

    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.fleetVehicleStatus),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in nextStatuses)
              ListTile(
                dense: true,
                title: Text(vehicleStatusLabel(s, status)),
                onTap: () => Navigator.pop(dialogContext, status),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (next == null) return;
    try {
      await ref
          .read(fleetRepositoryProvider)
          .updateVehicleStatus(orgId, vehicleId, status: next);
      ref.invalidate(orgVehiclesProvider(orgId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.fleetVehicleDetailTitle)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    final orgId = orgCtx.id;
    final canOperate = orgCtx.canOperate;
    final vehiclesAsync = ref.watch(orgVehiclesProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetVehicleDetailTitle)),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(orgVehiclesProvider(orgId)),
        ),
        data: (vehicles) {
          final vehicle = vehicles.where((v) => v.id == vehicleId).firstOrNull;
          if (vehicle == null) {
            return DcoEmptyState(
              title: s.fleetInventoryEmpty,
              body: s.fleetInventoryEmptyBody,
            );
          }
          final nextStatuses =
              lifecycleTransitions[vehicle.lifecycleTemplate]?[vehicle.status] ??
              const <String>[];
          final readyForTransfer = vehicle.lifecycleTemplate == 'showroom' &&
              vehicle.status == 'reserved';

          return ListView(
            padding: EdgeInsets.all(tokens.space.s3),
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(tokens.space.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusChip(
                            label: vehicleStatusLabel(s, vehicle.status),
                            tone: vehicleStatusTone(vehicle.status),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space.s3),
                      _Row(
                        label: s.vehiclePlateLabel,
                        value: vehicle.licensePlate,
                      ),
                      _Row(
                        label: s.vehicleMakeLabel,
                        value:
                            '${vehicle.make} ${vehicle.model} ${vehicle.year}',
                      ),
                      if (vehicle.vin != null && vehicle.vin!.isNotEmpty)
                        _Row(label: s.vehicleVinLabel, value: vehicle.vin!),
                      _Row(
                        label: s.vehicleMileageLabel,
                        value: '${vehicle.mileage} ${vehicle.mileageUnit}',
                      ),
                      _Row(
                        label: s.fleetVehicleTemplate,
                        value: lifecycleLabel(s, vehicle.lifecycleTemplate),
                      ),
                      if (vehicle.revenueLabel != null)
                        _Row(
                          label: s.fleetVehicleRevenueLabel,
                          value: vehicle.revenueLabel!,
                        ),
                      _Row(
                        label: s.fleetVehicleDriver,
                        value: vehicle.assignedDriverId != null
                            ? s.fleetAssignActive
                            : s.fleetInventoryUnassigned,
                      ),
                    ],
                  ),
                ),
              ),
              if (canOperate && nextStatuses.isNotEmpty) ...[
                SizedBox(height: tokens.space.s3),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.swap_horiz,
                      color: tokens.icon.inactive,
                    ),
                    title: Text(s.fleetVehicleStatus),
                    subtitle: Text(
                      nextStatuses
                          .map((status) => vehicleStatusLabel(s, status))
                          .join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.caption,
                      ),
                    ),
                    onTap: () => _changeStatus(
                      context,
                      ref,
                      orgId,
                      vehicle.lifecycleTemplate,
                      vehicle.status,
                    ),
                  ),
                ),
              ],
              if (canOperate && readyForTransfer) ...[
                SizedBox(height: tokens.space.s3),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.handshake_outlined,
                      color: tokens.icon.inactive,
                    ),
                    title: Text(s.fleetVehicleTransfer),
                    subtitle: Text(
                      s.fleetVehicleTransferHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.caption,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: tokens.icon.inactive,
                    ),
                    onTap: () => context.push(
                      AppRoutes.fleetVehicleTransfer(vehicleId),
                    ),
                  ),
                ),
              ],
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

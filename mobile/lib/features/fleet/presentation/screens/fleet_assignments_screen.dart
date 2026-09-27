import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Driver assignments: active + history, with assign / unassign for
/// admin and manager.
class FleetAssignmentsScreen extends ConsumerWidget {
  const FleetAssignmentsScreen({super.key});

  String _shortId(String id) =>
      id.length > 8 ? id.substring(0, 8) : id;

  Future<void> _unassign(
    BuildContext context,
    WidgetRef ref,
    String orgId,
    String assignmentId,
  ) async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.fleetAssignUnassignConfirmTitle),
        content: Text(s.fleetAssignUnassignConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.fleetAssignUnassign),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(fleetRepositoryProvider)
          .unassignVehicle(orgId, assignmentId);
      ref.invalidate(assignmentsProvider(orgId));
      ref.invalidate(orgVehiclesProvider(orgId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    }
  }

  Future<void> _assign(BuildContext context, WidgetRef ref, String orgId) async {
    final s = AppLocalizations.of(context)!;
    final vehicles =
        ref.read(orgVehiclesProvider(orgId)).valueOrNull ?? const [];
    final members = ref.read(orgMembersProvider(orgId)).valueOrNull ?? const [];
    final assignments =
        ref.read(assignmentsProvider(orgId)).valueOrNull ?? const [];

    final activeVehicleIds = {
      for (final a in assignments)
        if (a.isActive) a.vehicleId,
    };
    final activeDriverIds = {
      for (final a in assignments)
        if (a.isActive) a.driverId,
    };
    final availableVehicles = [
      for (final v in vehicles)
        if (!activeVehicleIds.contains(v.id) && !v.archived) v,
    ];
    final drivers = [
      for (final m in members)
        if (m.role == 'org_driver' && !activeDriverIds.contains(m.userId)) m,
    ];
    if (availableVehicles.isEmpty || drivers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fleetAssignNoVehicles)));
      return;
    }

    String? vehicleId = availableVehicles.first.id;
    String? driverId = drivers.first.userId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.fleetAssignAssign),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: vehicleId,
                decoration: InputDecoration(labelText: s.fleetAssignVehicleLabel),
                items: [
                  for (final vehicle in availableVehicles)
                    DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(
                        '${vehicle.displayName} · ${vehicle.licensePlate}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setDialogState(() => vehicleId = v),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: driverId,
                decoration: InputDecoration(labelText: s.fleetAssignDriverLabel),
                items: [
                  for (final driver in drivers)
                    DropdownMenuItem(
                      value: driver.userId,
                      child: Text(driver.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setDialogState(() => driverId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true || vehicleId == null || driverId == null) return;
    try {
      await ref
          .read(fleetRepositoryProvider)
          .assignVehicle(orgId, vehicleId!, driverId!);
      ref.invalidate(assignmentsProvider(orgId));
      ref.invalidate(orgVehiclesProvider(orgId));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetAssignDone)));
      }
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
        appBar: AppBar(title: Text(s.fleetHubAssignments)),
          body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    final orgId = orgCtx.id;
    final canOperate = orgCtx.canOperate;
    final assignmentsAsync = ref.watch(assignmentsProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.fleetHubAssignments),
        actions: [
          if (canOperate)
            IconButton(
              tooltip: s.fleetAssignAssign,
              icon: const Icon(Icons.person_add_alt),
              onPressed: () => _assign(context, ref, orgId),
            ),
        ],
      ),
      body: assignmentsAsync.when(
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
                onAction: () => ref.invalidate(assignmentsProvider(orgId)),
              ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return DcoEmptyState(
              title: s.fleetAssignmentsEmpty,
              body: s.fleetAssignmentsEmptyBody,
              actionLabel: canOperate ? s.fleetAssignAssign : null,
              onAction: canOperate
                  ? () => _assign(context, ref, orgId)
                  : null,
            );
          }
          final active = assignments.where((a) => a.isActive).toList();
          final history = assignments.where((a) => !a.isActive).toList();
          return ListView(
            padding: EdgeInsets.all(tokens.space.s3),
            children: [
              for (final assignment in active)
                Card(
                  margin: EdgeInsets.only(bottom: tokens.space.s2),
                  child: ListTile(
                    leading: Icon(
                      Icons.assignment_ind,
                      color: tokens.icon.inactive,
                    ),
                    title: Text(
                      '${_shortId(assignment.vehicleId)} · '
                      '${_shortId(assignment.driverId)}',
                    ),
                    subtitle: Text(
                      assignment.assignedAt ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.caption,
                      ),
                    ),
                    trailing: StatusChip(
                      label: s.fleetAssignActive,
                      tone: 'success',
                    ),
                    onTap: canOperate
                        ? () => _unassign(
                            context,
                            ref,
                            orgId,
                            assignment.id,
                          )
                        : null,
                  ),
                ),
              if (history.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: tokens.space.s3,
                    bottom: tokens.space.s2,
                  ),
                  child: Text(
                    s.fleetAssignHistory,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.text.secondary,
                    ),
                  ),
                ),
              for (final assignment in history)
                Card(
                  margin: EdgeInsets.only(bottom: tokens.space.s2),
                  child: ListTile(
                    leading: Icon(
                      Icons.history,
                      color: tokens.icon.inactive,
                    ),
                    title: Text(
                      '${_shortId(assignment.vehicleId)} · '
                      '${_shortId(assignment.driverId)}',
                    ),
                    subtitle: Text(
                      assignment.unassignedAt ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.caption,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

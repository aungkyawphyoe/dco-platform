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

/// Fleet mode Maintenance tab: organization work orders with status filter.
class FleetWorkOrdersScreen extends ConsumerStatefulWidget {
  const FleetWorkOrdersScreen({super.key});

  @override
  ConsumerState<FleetWorkOrdersScreen> createState() =>
      _FleetWorkOrdersScreenState();
}

class _FleetWorkOrdersScreenState
    extends ConsumerState<FleetWorkOrdersScreen> {
  /// null = all
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;

    if (orgCtx == null) {
      return DcoEmptyState(
        title: s.fleetNoAccessTitle,
        body: s.fleetNoAccessBody,
      );
    }
    final orgId = orgCtx.id;
    final workOrdersAsync = ref.watch(orgWorkOrdersProvider(orgId));

    return Scaffold(
      backgroundColor: tokens.background.primary,
      appBar: AppBar(title: Text(s.fleetWorkOrdersTitle)),
      body: workOrdersAsync.when(
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
                onAction: () => ref.invalidate(orgWorkOrdersProvider(orgId)),
              ),
        data: (workOrders) {
          final filtered = _statusFilter == null
              ? workOrders
              : workOrders.where((w) => w.status == _statusFilter).toList();
          if (workOrders.isEmpty) {
            return DcoEmptyState(
              title: s.fleetWorkOrdersEmpty,
              body: s.fleetWorkOrdersEmptyBody,
            );
          }
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space.s3,
                  tokens.space.s3,
                  tokens.space.s3,
                  tokens.space.s1,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: s.fleetWoFilterAll,
                      selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                    SizedBox(width: tokens.space.s2),
                    _FilterChip(
                      label: s.fleetWoStatusReported,
                      selected: _statusFilter == 'reported',
                      onTap: () =>
                          setState(() => _statusFilter = 'reported'),
                    ),
                    SizedBox(width: tokens.space.s2),
                    _FilterChip(
                      label: s.fleetWoStatusInProgress,
                      selected: _statusFilter == 'in_progress',
                      onTap: () =>
                          setState(() => _statusFilter = 'in_progress'),
                    ),
                    SizedBox(width: tokens.space.s2),
                    _FilterChip(
                      label: s.fleetWoStatusCompleted,
                      selected: _statusFilter == 'completed',
                      onTap: () =>
                          setState(() => _statusFilter = 'completed'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? DcoEmptyState(
                        title: s.fleetWorkOrdersEmpty,
                        body: s.fleetWorkOrdersEmptyBody,
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(tokens.space.s3),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final workOrder = filtered[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: tokens.space.s2),
                            child: ListTile(
                              leading: Icon(
                                Icons.build_outlined,
                                color: tokens.icon.inactive,
                              ),
                              title: Text(
                                issueTypeLabel(s, workOrder.issueType),
                              ),
                              subtitle: Text(
                                workOrder.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: tokens.text.caption),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusChip(
                                    label: workOrderStatusLabel(
                                      s,
                                      workOrder.status,
                                    ),
                                    tone: workOrderTone(workOrder.status),
                                  ),
                                  SizedBox(height: tokens.space.s1),
                                  StatusChip(
                                    label: urgencyLabel(s, workOrder.urgency),
                                    tone: urgencyTone(workOrder.urgency),
                                  ),
                                ],
                              ),
                              onTap: () => context.push(
                                AppRoutes.fleetWorkOrder(workOrder.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius.full),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space.s3,
          vertical: tokens.space.s1,
        ),
        decoration: BoxDecoration(
          color: selected
              ? tokens.button.primary.background
              : tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.full),
          border: Border.all(color: tokens.border.divider),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected
                ? tokens.button.primary.text
                : tokens.text.secondary,
          ),
        ),
      ),
    );
  }
}

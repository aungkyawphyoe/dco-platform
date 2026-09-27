import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Work order detail. Admin/manager can advance the status
/// (reported → in_progress → completed); drivers see read-only.
class FleetWorkOrderDetailScreen extends ConsumerWidget {
  const FleetWorkOrderDetailScreen({super.key, required this.workOrderId});

  final String workOrderId;

  Future<void> _update(
    BuildContext context,
    WidgetRef ref, {
    required String orgId,
    required String status,
    String? resolutionNotes,
  }) async {
    final s = AppLocalizations.of(context)!;
    try {
      await ref
          .read(fleetRepositoryProvider)
          .updateWorkOrder(
            orgId,
            workOrderId,
            status: status,
            resolutionNotes: resolutionNotes,
          );
      ref.invalidate(orgWorkOrdersProvider(orgId));
      ref.invalidate(driverWorkOrdersProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    }
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref, {
    required String orgId,
  }) async {
    final s = AppLocalizations.of(context)!;
    final notesController = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.fleetWoResolve),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: s.fleetWoResolutionNotes,
            hintText: s.fleetWoResolutionNotesHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, notesController.text.trim()),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (notes == null || !context.mounted) return;
    await _update(
      context,
      ref,
      orgId: orgId,
      status: 'completed',
      resolutionNotes: notes.isEmpty ? null : notes,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.fleetWoDetailTitle)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    final orgId = orgCtx.id;
    final canOperate = orgCtx.canOperate;
    final workOrdersAsync = ref.watch(orgWorkOrdersProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetWoDetailTitle)),
      body: workOrdersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(orgWorkOrdersProvider(orgId)),
        ),
        data: (workOrders) {
          final workOrder = workOrders
              .where((w) => w.id == workOrderId)
              .firstOrNull;
          if (workOrder == null) {
            return DcoEmptyState(
              title: s.fleetWorkOrdersEmpty,
              body: s.fleetWorkOrdersEmptyBody,
            );
          }
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
                              issueTypeLabel(s, workOrder.issueType),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusChip(
                            label: workOrderStatusLabel(s, workOrder.status),
                            tone: workOrderTone(workOrder.status),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space.s2),
                      Wrap(
                        spacing: tokens.space.s2,
                        children: [
                          StatusChip(
                            label: urgencyLabel(s, workOrder.urgency),
                            tone: urgencyTone(workOrder.urgency),
                          ),
                          StatusChip(label: workOrder.status, tone: 'info'),
                        ],
                      ),
                      SizedBox(height: tokens.space.s3),
                      Text(
                        workOrder.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: tokens.space.s3),
                      _Row(
                        label: s.fleetWoOdometerKm,
                        value: '${workOrder.odometerKm}',
                      ),
                      _Row(
                        label: s.fleetWoReportedBy,
                        value: workOrder.reportedBy,
                      ),
                      if (workOrder.assignedTo != null)
                        _Row(
                          label: s.fleetWoAssignedTo,
                          value: workOrder.assignedTo!,
                        ),
                      if (workOrder.reportedAt != null)
                        _Row(
                          label: s.fleetWoReported,
                          value: workOrder.reportedAt!,
                        ),
                      if (workOrder.resolutionNotes?.isNotEmpty ?? false)
                        _Row(
                          label: s.fleetWoResolutionNotes,
                          value: workOrder.resolutionNotes!,
                        ),
                    ],
                  ),
                ),
              ),
              if (canOperate && workOrder.status == 'reported') ...[
                SizedBox(height: tokens.space.s4),
                DcoButton(
                  label: s.fleetWoStart,
                  onPressed: () => _update(
                    context,
                    ref,
                    orgId: orgId,
                    status: 'in_progress',
                  ),
                ),
              ],
              if (canOperate && workOrder.status == 'in_progress') ...[
                SizedBox(height: tokens.space.s4),
                DcoButton(
                  label: s.fleetWoResolve,
                  onPressed: () =>
                      _resolve(context, ref, orgId: orgId),
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

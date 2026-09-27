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

/// Driver mode Maintenance tab: my work orders and inspections.
class DriverMyReportsScreen extends ConsumerStatefulWidget {
  const DriverMyReportsScreen({super.key});

  @override
  ConsumerState<DriverMyReportsScreen> createState() =>
      _DriverMyReportsScreenState();
}

class _DriverMyReportsScreenState
    extends ConsumerState<DriverMyReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final workOrdersAsync = ref.watch(driverWorkOrdersProvider);
    final inspectionsAsync = ref.watch(driverInspectionsProvider);

    return Scaffold(
      backgroundColor: tokens.background.primary,
      appBar: AppBar(
        title: Text(s.driverMyReportsTab),
        bottom: TabBar(
          controller: _tabController,
          labelColor: tokens.text.accent,
          unselectedLabelColor: tokens.text.tertiary,
          indicatorColor: tokens.text.accent,
          tabs: [
            Tab(text: s.driverReportsWorkOrders),
            Tab(text: s.driverReportsInspections),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Work orders ──
          workOrdersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(driverWorkOrdersProvider),
            ),
            data: (workOrders) {
              if (workOrders.isEmpty) {
                return DcoEmptyState(
                  title: s.driverMyWorkOrdersEmpty,
                  body: s.driverMyWorkOrdersEmptyBody,
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(tokens.space.s3),
                itemCount: workOrders.length,
                itemBuilder: (context, index) {
                  final workOrder = workOrders[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: tokens.space.s2),
                    child: ListTile(
                      leading: Icon(
                        Icons.build_outlined,
                        color: tokens.icon.inactive,
                      ),
                      title: Text(issueTypeLabel(s, workOrder.issueType)),
                      subtitle: Text(
                        workOrder.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.caption,
                        ),
                      ),
                      trailing: StatusChip(
                        label: workOrderStatusLabel(s, workOrder.status),
                        tone: workOrderTone(workOrder.status),
                      ),
                      onTap: () => context.push(
                        AppRoutes.fleetWorkOrder(workOrder.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // ── Inspections ──
          inspectionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(driverInspectionsProvider),
            ),
            data: (inspections) {
              if (inspections.isEmpty) {
                return DcoEmptyState(
                  title: s.driverInspectionsEmpty,
                  body: s.driverInspectionsEmpty,
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(tokens.space.s3),
                itemCount: inspections.length,
                itemBuilder: (context, index) {
                  final inspection = inspections[index];
                  final failed = inspection.status == 'failed';
                  final done = inspection.status == 'completed';
                  return Card(
                    margin: EdgeInsets.only(bottom: tokens.space.s2),
                    child: ListTile(
                      leading: Icon(
                        Icons.checklist_outlined,
                        color: tokens.icon.inactive,
                      ),
                      title: Text(
                        inspection.inspectionType == 'post_trip'
                            ? s.driverInspectionTypePost
                            : s.driverInspectionTypePre,
                      ),
                      subtitle: Text(
                        inspection.startedAt ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.caption,
                        ),
                      ),
                      trailing: StatusChip(
                        label: failed
                            ? s.driverInspectionFailed
                            : done
                            ? s.driverInspectionCompleted
                            : s.fleetWoStatusInProgress,
                        tone: failed
                            ? 'danger'
                            : done
                            ? 'success'
                            : 'warning',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_service_record.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Driver Maintenance tab (Confirmed Access Decisions 16–20) — personal-mode
/// parity for the assigned vehicle, online-first:
///
/// * **Register service** button → Report | Do myself form
/// * Plan (read-only rows + "Log" + suggested adds)
/// * Merged history: service records (Completed) + maintenance-Report work
///   orders (Reported → Completed on refresh)
class DriverMaintenanceScreen extends ConsumerWidget {
  const DriverMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final myVehicleAsync = ref.watch(driverMyVehicleProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu, color: tokens.icon.active),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text(s.maintenanceTitle),
      ),
      body: myVehicleAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(driverMyVehicleProvider),
        ),
        data: (ctx) {
          if (!ctx.hasAssignedVehicle) {
            return DcoEmptyState(
              title: s.driverNoVehicleTitle,
              body: s.driverNoVehicleBody,
            );
          }
          final vehicle = ctx.vehicle!;
          final plan = ref.watch(driverPlanItemsProvider(vehicle.id));
          final history = ref.watch(
            driverMaintenanceHistoryProvider(vehicle.id),
          );

          final planItems = plan.valueOrNull ?? const [];
          final historyEntries = history.valueOrNull ?? const [];
          final now = DateTime.now();
          final sortedPlan = [...planItems]
            ..sort((a, b) {
              final aOverdue = a.isOverdue(
                now: now,
                currentMileage: vehicle.mileage,
              );
              final bOverdue = b.isOverdue(
                now: now,
                currentMileage: vehicle.mileage,
              );
              if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
              return a.name.compareTo(b.name);
            });

          return RefreshIndicator(
            color: tokens.text.accent,
            onRefresh: () async {
              ref
                ..invalidate(driverPlanItemsProvider(vehicle.id))
                ..invalidate(driverMaintenanceHistoryProvider(vehicle.id));
            },
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s3),
              children: [
                DcoButton(
                  label: s.maintenanceRegisterService,
                  onPressed: () => context.push(AppRoutes.driverRegisterService),
                ),
                SectionHeader(s.driverMaintenancePlanTitle),
                if (plan.isLoading && planItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sortedPlan.isEmpty)
                  _EmptyHint(s.driverMaintenancePlanEmptyBody)
                else
                  ...sortedPlan.map((item) {
                    final overdue = item.isOverdue(
                      now: now,
                      currentMileage: vehicle.mileage,
                    );
                    return Card(
                      margin: EdgeInsets.only(bottom: tokens.space.s2),
                      child: ListTile(
                        leading: Icon(
                          Icons.build_outlined,
                          color: overdue
                              ? tokens.status.dangerFg
                              : tokens.icon.inactive,
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          [
                            if (item.nextDueOn != null)
                              '${s.driverPlanDue} ${item.nextDueOn}',
                            if (item.nextDueMileage != null)
                              '${item.nextDueMileage} km',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.caption),
                        ),
                        trailing: overdue
                            ? StatusChip(label: s.overdue, tone: 'danger')
                            : TextButton(
                                onPressed: () => context.push(
                                  '${AppRoutes.driverRegisterService}?plan=${item.id}',
                                ),
                                child: Text(s.driverRegisterLogAction),
                              ),
                      ),
                    );
                  }),
                SectionHeader(s.driverHistoryTitle),
                if (history.isLoading && historyEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (history.hasError)
                  _EmptyHint(s.serviceHistoryLoadError)
                else if (historyEntries.isEmpty)
                  _EmptyHint(s.driverHistoryEmptyBody)
                else
                  ...historyEntries.map(
                    (entry) => Card(
                      margin: EdgeInsets.only(bottom: tokens.space.s2),
                      child: ListTile(
                        leading: Icon(
                          entry.isWorkOrder
                              ? Icons.flag_outlined
                              : Icons.check_circle_outline,
                          color: tokens.icon.inactive,
                        ),
                        title: Text(
                          entry.title.isEmpty
                              ? (entry.isWorkOrder
                                  ? s.fleetWoReportTitle
                                  : s.maintenanceRegisterService)
                              : entry.title,
                        ),
                        subtitle: Text(
                          [
                            DateFormat.yMMMd().format(entry.servicedOn),
                            '${entry.odometer.round()} km',
                            if (entry.totalCost != null)
                              '${entry.totalCost!.round()}',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.caption),
                        ),
                        trailing: StatusChip(
                          label: entry.isWorkOrder
                              ? _workOrderStatusLabel(s, entry)
                              : s.fleetWoStatusCompleted,
                          tone: entry.isWorkOrder
                              ? workOrderTone(entry.workOrderStatus ?? '')
                              : 'success',
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: tokens.space.s6),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _workOrderStatusLabel(
    AppLocalizations s,
    DriverHistoryEntry entry,
  ) {
    return switch (entry.workOrderStatus) {
      'in_progress' => s.fleetWoStatusInProgress,
      'completed' => s.fleetWoStatusCompleted,
      _ => s.fleetWoStatusReported,
    };
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space.s2),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
      ),
    );
  }
}

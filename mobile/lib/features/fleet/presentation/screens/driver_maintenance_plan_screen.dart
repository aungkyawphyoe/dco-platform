import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Driver mode: the assigned vehicle's maintenance plan (online-first).
/// Plan rows are server-generated (template snapshot) or added by the
/// driver from the suggested list.
class DriverMaintenancePlanScreen extends ConsumerWidget {
  const DriverMaintenancePlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final myVehicleAsync = ref.watch(driverMyVehicleProvider);

    return Scaffold(
      backgroundColor: tokens.background.primary,
      appBar: AppBar(title: Text(s.driverMaintenancePlanTitle)),
      body: myVehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
          final planAsync = ref.watch(driverPlanItemsProvider(vehicle.id));

          return planAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () =>
                  ref.invalidate(driverPlanItemsProvider(vehicle.id)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return DcoEmptyState(
                  title: s.driverMaintenancePlanEmpty,
                  body: s.driverMaintenancePlanEmptyBody,
                );
              }
              final now = DateTime.now();
              final mileage = vehicle.mileage;
              final sorted = [...items]
                ..sort(
                  (a, b) => _compare(a, b, now: now, mileage: mileage),
                );

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(tokens.space.s3),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final item = sorted[index];
                        final overdue = item.isOverdue(
                          now: now,
                          currentMileage: mileage,
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
                              _subtitle(s, item),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.text.caption),
                            ),
                            trailing: overdue
                                ? StatusChip(
                                    label: s.overdue,
                                    tone: 'danger',
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        tokens.space.s3,
                        tokens.space.s2,
                        tokens.space.s3,
                        tokens.space.s3,
                      ),
                      child: DcoButton(
                        label: s.driverMaintenancePlanAddSuggested,
                        onPressed: () => context
                            .push(AppRoutes.driverMaintenanceSuggested),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static int _compare(
    DriverPlanItem a,
    DriverPlanItem b, {
    required DateTime now,
    required int mileage,
  }) {
    if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
    final aOverdue = a.isOverdue(now: now, currentMileage: mileage);
    final bOverdue = b.isOverdue(now: now, currentMileage: mileage);
    if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
    return a.name.compareTo(b.name);
  }

  static String _subtitle(AppLocalizations s, DriverPlanItem item) {
    final interval = <String>[
      if (item.intervalDays != null) '${item.intervalDays}d',
      if (item.intervalDistance != null)
        '${item.intervalDistance!.round()} km',
    ].join(' · ');
    final due = <String>[
      if (item.nextDueOn != null) item.nextDueOn!,
      if (item.nextDueMileage != null) '${item.nextDueMileage} km',
    ].join(' · ');
    return [
      if (interval.isNotEmpty) interval,
      if (due.isNotEmpty) '${s.driverPlanDue} $due',
    ].join(' — ');
  }
}

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/plan_item_tile.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/section_header.dart';

import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final active = ref.watch(activeVehicleProvider);
    final plan = ref.watch(maintenancePlanProvider);
    final lengthUnit = ref.watch(lengthUnitProvider);
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu, color: tokens.icon.active),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text(s.maintenanceTitle),
        actions: [
          IconButton(
            tooltip: s.maintenanceHistoryTooltip,
            onPressed: () => context.push(AppRoutes.serviceHistory),
            icon: Icon(Icons.work_history_outlined, color: tokens.icon.active),
          ),
        ],
      ),
      body: active.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) =>
            DcoEmptyState(title: s.maintenanceLoadError, body: '$error'),
        data: (vehicle) {
          if (vehicle == null) {
            return DcoEmptyState(
              title: s.maintenanceNoActiveVehicle,
              body: s.maintenanceNoActiveVehicleBody,
            );
          }
          final items = plan.valueOrNull ?? const <PlanItem>[];
          final now = DateTime.now();
          final upcoming = items.where((item) {
            final urgency = DueCalculator.urgency(
              item: item,
              vehicleMileage: vehicle.mileage,
              now: now,
            );
            return DueCalculator.isUpcoming(urgency);
          }).toList();
          final scheduled = items.where((item) {
            return DueCalculator.urgency(
                  item: item,
                  vehicleMileage: vehicle.mileage,
                  now: now,
                ) ==
                PlanUrgency.scheduled;
          }).toList();
          upcoming.sort(
            (a, b) => DueCalculator.compareSoonest(a, b, vehicle.mileage, now),
          );
          scheduled.sort(
            (a, b) => DueCalculator.compareSoonest(a, b, vehicle.mileage, now),
          );

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        MaintenanceSectionHeader(
                          title: s.maintenanceUpcomingReminders,
                          tone: MaintenanceSectionTone.danger,
                          trailing: upcoming.isEmpty
                              ? null
                              : '${upcoming.length} due',
                        ),
                        SizedBox(height: tokens.space.s3),
                        if (upcoming.isEmpty)
                          _SectionEmpty(label: s.maintenanceNothingDue)
                        else
                          ...upcoming.map(
                            (item) => PlanItemTile(
                              item: item,
                              vehicle: vehicle,
                              now: now,
                              lengthUnit: lengthUnit,
                              onTap: () => context.push(
                                AppRoutes.maintenanceRegisterItem(item.id),
                              ),
                            ),
                          ),
                        MaintenanceSectionHeader(
                          title: s.maintenanceScheduled,
                          tone: MaintenanceSectionTone.info,
                        ),
                        SizedBox(height: tokens.space.s3),
                        if (scheduled.isEmpty)
                          _SectionEmpty(label: s.maintenanceNothingScheduled)
                        else
                          ...scheduled.map(
                            (item) => PlanItemTile(
                              item: item,
                              vehicle: vehicle,
                              now: now,
                              lengthUnit: lengthUnit,
                              onTap: () => context.push(
                                AppRoutes.maintenanceRegisterItem(item.id),
                              ),
                            ),
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),

                  // DcoStickyActions(
                  //   secondaryLabel: s.maintenanceRegisterService,
                  //   onSecondary: () => context.push(AppRoutes.maintenanceRegister),
                  //   primaryLabel: s.maintenanceLoadFromReceipt,
                  //   onPrimary: () {},
                  // ),
                  // SizedBox(height: 70.0),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 90,
                child: SizedBox(
                  width: 150.0,
                  height: 56.0,
                  child: FloatingActionButton.extended(
                    backgroundColor: tokens.button.primary.background,
                    foregroundColor: tokens.text.inverse,
                    onPressed: () =>
                        context.push(AppRoutes.maintenanceRegister),
                    label: Text(s.dashboardLogService),
                    icon: const Icon(Icons.car_repair),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radius.full),
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

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space.s4,
        0,
        tokens.space.s4,
        tokens.space.s4,
      ),
      child: Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          boxShadow: tokens.shadows.card,
        ),
        child: Text(label, style: TextStyle(color: tokens.text.accent)),
      ),
    );
  }
}

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/plan_item_tile.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/section_header.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
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
    final history = ref.watch(maintenanceHistoryProvider);
    final lengthUnit = ref.watch(lengthUnitProvider);
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.maintenanceTitle),
        actions: [
          TextButton(
            onPressed: active.valueOrNull == null
                ? null
                : () => _openPlan(context, ref),
            child: Text(
              s.maintenancePlanLink,
              style: TextStyle(color: tokens.text.link, fontSize: 13),
            ),
          ),
        ],
      ),
      body: active.when(
        loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) => DcoEmptyState(title: s.maintenanceLoadError, body: '$error'),
        data: (vehicle) {
          if (vehicle == null) {
            return DcoEmptyState(
              title: s.maintenanceNoActiveVehicle,
              body: s.maintenanceNoActiveVehicleBody,
            );
          }
          final items = plan.valueOrNull ?? const <PlanItem>[];
          final records = history.valueOrNull ?? const [];
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
          upcoming.sort((a, b) => DueCalculator.compareSoonest(a, b, vehicle.mileage, now));
          scheduled.sort((a, b) => DueCalculator.compareSoonest(a, b, vehicle.mileage, now));

          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    MaintenanceSectionHeader(
                      title: s.maintenanceUpcomingReminders,
                      tone: MaintenanceSectionTone.danger,
                      trailing: upcoming.isEmpty ? null : '${upcoming.length} due',
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
                          onTap: () => context.push(AppRoutes.maintenanceRegisterItem(item.id)),
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
                          onTap: () => context.push(AppRoutes.maintenanceRegisterItem(item.id)),
                        ),
                      ),
                    MaintenanceSectionHeader(title: s.maintenanceServiceHistory),
                    SizedBox(height: tokens.space.s3),
                    if (records.isEmpty)
                      _SectionEmpty(label: s.maintenanceNoServicesLogged)
                    else
                      ...records.map(
                        (record) => HistoryTile(
                          record: record,
                          lengthUnit: lengthUnit,
                          currency: currency,
                          onTap: () => context.push(AppRoutes.serviceDetail(record.id)),
                        ),
                      ),
                    SizedBox(height: tokens.space.s4),
                  ],
                ),
              ),
              DcoStickyActions(
                secondaryLabel: s.maintenanceRegisterService,
                onSecondary: () => context.push(AppRoutes.maintenanceRegister),
                primaryLabel: s.maintenanceLoadFromReceipt,
                onPrimary: () {},
              ),
              SizedBox(height: 70.0)
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPlan(BuildContext context, WidgetRef ref) async {
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    await ref.read(maintenanceRepositoryProvider).ensureDefaultPlan(
      userId: vehicle.userId,
      vehicle: vehicle,
    );
    if (context.mounted) context.push(AppRoutes.maintenancePlan    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, 0, tokens.space.s4, tokens.space.s4),
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

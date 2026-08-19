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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final active = ref.watch(activeVehicleProvider);
    final plan = ref.watch(maintenancePlanProvider);
    final history = ref.watch(maintenanceHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        actions: [
          TextButton(
            onPressed: active.valueOrNull == null
                ? null
                : () => _openPlan(context, ref),
            child: Text(
              'maintenance plan',
              style: TextStyle(color: tokens.text.link, fontSize: 13),
            ),
          ),
        ],
      ),
      body: active.when(
        loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) => DcoEmptyState(title: 'Could not load maintenance', body: '$error'),
        data: (vehicle) {
          if (vehicle == null) {
            return const DcoEmptyState(
              title: 'No active vehicle',
              body: 'Register a vehicle to plan service and keep history.',
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
          upcoming.sort(_bySoonest(vehicle.mileage, now));
          scheduled.sort(_bySoonest(vehicle.mileage, now));

          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    MaintenanceSectionHeader(
                      title: 'Upcoming Reminders',
                      tone: MaintenanceSectionTone.danger,
                      trailing: upcoming.isEmpty ? null : '${upcoming.length} due',
                    ),
                    SizedBox(height: tokens.space.s3),
                    if (upcoming.isEmpty)
                      _SectionEmpty(label: 'Nothing due')
                    else
                      ...upcoming.map(
                        (item) => PlanItemTile(
                          item: item,
                          vehicle: vehicle,
                          now: now,
                          onTap: () => context.push(AppRoutes.maintenanceRegisterItem(item.id)),
                        ),
                      ),
                    MaintenanceSectionHeader(
                      title: 'Scheduled',
                      tone: MaintenanceSectionTone.info,
                    ),
                    SizedBox(height: tokens.space.s3),
                    if (scheduled.isEmpty)
                      _SectionEmpty(label: 'Nothing scheduled')
                    else
                      ...scheduled.map(
                        (item) => PlanItemTile(
                          item: item,
                          vehicle: vehicle,
                          now: now,
                          onTap: () => context.push(AppRoutes.maintenanceRegisterItem(item.id)),
                        ),
                      ),
                    const MaintenanceSectionHeader(title: 'Service History'),
                    SizedBox(height: tokens.space.s3),
                    if (records.isEmpty)
                      _SectionEmpty(label: 'No services logged')
                    else
                      ...records.map(
                        (record) => HistoryTile(
                          record: record,
                          unit: vehicle.mileageUnit.label,
                          onTap: () => context.push(AppRoutes.serviceDetail(record.id)),
                        ),
                      ),
                    SizedBox(height: tokens.space.s4),
                  ],
                ),
              ),
              DcoStickyActions(
                secondaryLabel: 'Register service',
                onSecondary: () => context.push(AppRoutes.maintenanceRegister),
                primaryLabel: 'Load from Receipt',
                onPrimary: () {},
              ),
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
    if (context.mounted) context.push(AppRoutes.maintenancePlan);
  }
}

int Function(PlanItem, PlanItem) _bySoonest(double mileage, DateTime now) {
  return (a, b) {
    final aDays = a.nextDueOn == null
        ? 1 << 20
        : DueCalculator.dateOnly(a.nextDueOn!).difference(DueCalculator.dateOnly(now)).inDays;
    final bDays = b.nextDueOn == null
        ? 1 << 20
        : DueCalculator.dateOnly(b.nextDueOn!).difference(DueCalculator.dateOnly(now)).inDays;
    final aMiles = a.nextDueMileage == null ? 1 << 20 : (a.nextDueMileage! - mileage);
    final bMiles = b.nextDueMileage == null ? 1 << 20 : (b.nextDueMileage! - mileage);
    final aRank = aDays < aMiles ? aDays : aMiles.round();
    final bRank = bDays < bMiles ? bDays : bMiles.round();
    return aRank.compareTo(bRank);
  };
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
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
        child: Text(label, style: TextStyle(color: tokens.text.accent)),
      ),
    );
  }
}

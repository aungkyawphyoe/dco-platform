import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/plan_item_tile.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MaintenancePlanScreen extends ConsumerWidget {
  const MaintenancePlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final plan = ref.watch(maintenancePlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Plan')),
      body: vehicle == null
          ? const DcoEmptyState(
              title: 'No active vehicle',
              body: 'Register a vehicle to build a maintenance plan.',
            )
          : Column(
              children: [
                Expanded(
                  child: plan.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: tokens.text.accent),
                    ),
                    error: (error, _) => DcoEmptyState(
                      title: 'Could not load plan',
                      body: '$error',
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const DcoEmptyState(
                          title: 'No plan items yet',
                          body: 'Add a custom item or pick from suggested services.',
                        );
                      }
                      final now = DateTime.now();
                      return ListView(
                        padding: EdgeInsets.only(top: tokens.space.s4),
                        children: [
                          ...items.map(
                            (item) => PlanItemTile(
                              item: item,
                              vehicle: vehicle,
                              now: now,
                              onTap: () => context.push(AppRoutes.maintenancePlanEdit(item.id)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                DcoStickyActions(
                  secondaryLabel: 'Add Maintenance Item',
                  onSecondary: () => context.push(AppRoutes.maintenancePlanNew),
                  primaryLabel: 'Add Suggested Items',
                  onPrimary: () => context.push(AppRoutes.maintenanceSuggested),
                ),
              ],
            ),
    );
  }
}

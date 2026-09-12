import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/plan_item_tile.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MaintenancePlanScreen extends ConsumerWidget {
  const MaintenancePlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final plan = ref.watch(maintenancePlanProvider);
    final lengthUnit = ref.watch(lengthUnitProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.maintenancePlanTitle)),
      body: vehicle == null
          ? DcoEmptyState(
              title: s.maintenanceNoActiveVehicle,
              body: s.maintenancePlanNoActiveVehicleBody,
            )
          : Column(
              children: [
                Expanded(
                  child: plan.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: tokens.text.accent),
                    ),
                    error: (error, _) => DcoEmptyState(
                      title: s.maintenancePlanLoadError,
                      body: '$error',
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return DcoEmptyState(
                          title: s.maintenancePlanEmptyTitle,
                          body: s.maintenancePlanEmptyBody,
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
                              lengthUnit: lengthUnit,
                              onTap: () => context.push(AppRoutes.maintenancePlanEdit(item.id)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                DcoStickyActions(
                  secondaryLabel: s.maintenancePlanAddItem,
                  onSecondary: () => context.push(AppRoutes.maintenancePlanNew),
                  primaryLabel: s.maintenancePlanAddSuggested,
                  onPrimary: () => context.push(AppRoutes.maintenanceSuggested),
                ),
              ],
            ),
    );
  }
}

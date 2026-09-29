import 'dart:async';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/plan_item_tile.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MaintenancePlanScreen extends ConsumerStatefulWidget {
  const MaintenancePlanScreen({super.key, this.showDone = false});

  final bool showDone;

  @override
  ConsumerState<MaintenancePlanScreen> createState() =>
      _MaintenancePlanScreenState();
}

class _MaintenancePlanScreenState extends ConsumerState<MaintenancePlanScreen> {
  final _seededVehicleIds = <String>{};

  void _seedDefaults(Vehicle vehicle) {
    if (!_seededVehicleIds.add(vehicle.id)) return;
    unawaited(
      ref.read(maintenanceRepositoryProvider).ensureDefaultPlan(
        userId: vehicle.userId,
        vehicle: vehicle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final plan = ref.watch(maintenancePlanProvider);
    final lengthUnit = ref.watch(lengthUnitProvider);
    final thresholds = ref.watch(reminderThresholdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.maintenancePlanTitle),
        actions: [
          if (widget.showDone)
            TextButton(
              key: const Key('maintenance-plan-done'),
              onPressed: () => context.go(AppRoutes.garage),
              child: Text(s.done, style: TextStyle(color: tokens.text.link)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: vehicle == null
                ? DcoEmptyState(
                    title: s.maintenanceNoActiveVehicle,
                    body: s.maintenancePlanNoActiveVehicleBody,
                  )
                : plan.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: tokens.text.accent,
                      ),
                    ),
                    error: (error, _) => DcoEmptyState(
                      title: s.maintenancePlanLoadError,
                      body: '$error',
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        _seedDefaults(vehicle);
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
                              thresholds: thresholds,
                              onTap: () => context.push(
                                AppRoutes.maintenancePlanEdit(item.id),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (vehicle != null)
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

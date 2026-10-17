import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/dashboard/presentation/widgets/quick_actions_grid.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Driver-mode Quick Actions (Confirmed Access Decision 15–24): the driver
/// set replaces the personal set on the Garage tab.
/// Report Issue · Start Inspection · Refuel · Notes.
class DriverQuickActions extends StatelessWidget {
  const DriverQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return QuickActionsGrid(
      items: [
        QuickActionItem(
          label: s.driverQuickReportIssue,
          icon: Icons.report_problem_outlined,
          color: tokens.chart.maintenance,
          onTap: () => context.push(AppRoutes.driverReportIssue),
        ),
        QuickActionItem(
          label: s.driverQuickStartInspection,
          icon: Icons.checklist_outlined,
          color: tokens.chart.other,
          onTap: () => context.push(AppRoutes.driverInspectionNew),
        ),
        QuickActionItem(
          label: s.driverQuickRefuel,
          icon: Icons.local_gas_station_outlined,
          color: tokens.chart.fuel,
          onTap: () => context.push(AppRoutes.driverFuelLog),
        ),
        QuickActionItem(
          label: s.driverQuickNotes,
          icon: Icons.notes_outlined,
          color: tokens.chart.other,
          onTap: () => context.push(AppRoutes.notes),
        ),
      ],
    );
  }
}

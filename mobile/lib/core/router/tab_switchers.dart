import 'package:dco_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:dco_mobile/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/driver_expenses_screen.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/driver_home_screen.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/driver_maintenance_screen.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Branch 0: personal Dashboard / Driver home (assigned vehicle + Quick
/// Actions). Driver mode keeps the Garage tab but the content is the driver's
/// assigned vehicle, not the personal garage.
class GarageTabScreen extends ConsumerWidget {
  const GarageTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(fleetModeProvider)) {
      FleetMode.driver => const DriverHomeScreen(),
      FleetMode.personal => const DashboardScreen(),
    };
  }
}

/// Branch 1: personal Maintenance / driver Maintenance (plan + Register
/// service Report | Do myself + merged history). Same four tabs in both
/// modes (Confirmed Access Decision 16).
class MaintenanceTabScreen extends ConsumerWidget {
  const MaintenanceTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(fleetModeProvider)) {
      FleetMode.driver => const DriverMaintenanceScreen(),
      FleetMode.personal => const MaintenanceScreen(),
    };
  }
}

/// Branch 2: personal Expenses / Driver fuel-only Expenses (no expense
/// categories — drivers log fuel only).
class ExpensesTabScreen extends ConsumerWidget {
  const ExpensesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(fleetModeProvider)) {
      FleetMode.driver => const DriverExpensesScreen(),
      FleetMode.personal => const ExpensesScreen(),
    };
  }
}

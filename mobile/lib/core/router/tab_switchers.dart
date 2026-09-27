import 'package:dco_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:dco_mobile/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/driver_my_reports_screen.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/driver_my_vehicle_screen.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/fleet_inventory_screen.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/fleet_reports_screen.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/fleet_work_orders_screen.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Branch 0: personal Dashboard / Fleet inventory / Driver my-vehicle.
class GarageTabScreen extends ConsumerWidget {
  const GarageTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(fleetModeProvider)) {
      FleetMode.fleet => const FleetInventoryScreen(),
      FleetMode.driver => const DriverMyVehicleScreen(),
      FleetMode.personal => const DashboardScreen(),
    };
  }
}

/// Branch 1: personal Maintenance / Fleet work orders / Driver my-reports.
class MaintenanceTabScreen extends ConsumerWidget {
  const MaintenanceTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(fleetModeProvider)) {
      FleetMode.fleet => const FleetWorkOrdersScreen(),
      FleetMode.driver => const DriverMyReportsScreen(),
      FleetMode.personal => const MaintenanceScreen(),
    };
  }
}

/// Branch 2: personal Expenses / Fleet analytics. Never shown in driver
/// mode (AppShell hides this destination).
class ExpensesTabScreen extends ConsumerWidget {
  const ExpensesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(fleetModeProvider)) {
      FleetMode.fleet => const FleetReportsScreen(),
      FleetMode.driver => const SizedBox.shrink(),
      FleetMode.personal => const ExpensesScreen(),
    };
  }
}

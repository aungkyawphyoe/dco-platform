import 'package:dco_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:dco_mobile/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:dco_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:flutter/material.dart';

/// Presentation is shared. Account context selects repositories and permissions.
class GarageTabScreen extends StatelessWidget {
  const GarageTabScreen({super.key});
  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

class MaintenanceTabScreen extends StatelessWidget {
  const MaintenanceTabScreen({super.key});
  @override
  Widget build(BuildContext context) => const MaintenanceScreen();
}

class ExpensesTabScreen extends StatelessWidget {
  const ExpensesTabScreen({super.key});
  @override
  Widget build(BuildContext context) => const ExpensesScreen();
}

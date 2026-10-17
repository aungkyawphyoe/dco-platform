import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../generated/app_localizations.dart';
import 'app_drawer.dart';
import '../widgets/custom_floating_nav_bar.dart';

/// Bottom shell. Four tabs in both modes — Driver mode is personal-mode
/// parity (Confirmed Access Decisions 15–24): Garage / Maintenance / Expenses
/// / Settings, with driver repositories mapping to org endpoints.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final currentBranch = widget.navigationShell.currentIndex;

    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Positioned.fill(child: widget.navigationShell),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CustomFloatingNavBar(
                currentIndex: currentBranch,
                items: [
                  CustomNavItem(
                    label: s.navGarage,
                    icon: Icons.directions_car_outlined,
                    activeIcon: Icons.directions_car,
                  ),
                  CustomNavItem(
                    label: s.navMaintenance,
                    icon: Icons.build_outlined,
                    activeIcon: Icons.build,
                  ),
                  CustomNavItem(
                    label: s.navExpenses,
                    icon: Icons.payments_outlined,
                    activeIcon: Icons.payments,
                  ),
                  CustomNavItem(
                    label: s.navSettings,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                  ),
                ],
                onTap: (index) {
                  widget.navigationShell.goBranch(
                    index,
                    initialLocation: index == currentBranch,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

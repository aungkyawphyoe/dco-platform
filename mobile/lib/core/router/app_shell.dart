import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/fleet/providers.dart';
import '../../generated/app_localizations.dart';
import 'app_drawer.dart';
import '../widgets/custom_floating_nav_bar.dart';

/// Bottom shell. Four tabs in Personal / Fleet mode; a restricted three-tab
/// view in Driver mode (My Vehicle / My Reports / Settings).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Driver mode hides branch 2 (Expenses); visible indices map to branches.
  static const _driverBranches = [0, 1, 3];

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isDriver = ref.watch(fleetModeProvider).name == 'driver';

    ref.listen(fleetModeProvider, (previous, next) {
      if (next.name == 'driver' && widget.navigationShell.currentIndex == 2) {
        widget.navigationShell.goBranch(0);
      }
    });

    final items = isDriver
        ? [
            CustomNavItem(
              label: s.driverMyVehicleTab,
              icon: Icons.directions_car_outlined,
              activeIcon: Icons.directions_car,
            ),
            CustomNavItem(
              label: s.driverMyReportsTab,
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment,
            ),
            CustomNavItem(
              label: s.navSettings,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
            ),
          ]
        : [
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
          ];

    final currentBranch = widget.navigationShell.currentIndex;
    final driverIndex = _driverBranches.indexOf(currentBranch);
    final currentIndex = !isDriver
        ? currentBranch
        : (driverIndex < 0 ? 0 : driverIndex);

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
                currentIndex: currentIndex,
                items: items,
                onTap: (index) {
                  final branch = isDriver ? _driverBranches[index] : index;
                  widget.navigationShell.goBranch(
                    branch,
                    initialLocation: branch == currentBranch,
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

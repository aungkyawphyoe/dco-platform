import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/widgets/tour_overlay.dart';
import '../../generated/app_localizations.dart';
import '../onboarding/tour_targets.dart';
import '../widgets/custom_floating_nav_bar.dart';
import 'app_drawer.dart';

/// Bottom shell. Four tabs in both modes — Driver mode is personal-mode
/// parity (Confirmed Access Decisions 15–24): Garage / Maintenance / Expenses
/// / More, with driver repositories mapping to org endpoints.
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
                    tourTarget: TourTarget.maintenance,
                  ),
                  CustomNavItem(
                    label: s.navExpenses,
                    icon: Icons.payments_outlined,
                    activeIcon: Icons.payments,
                    tourTarget: TourTarget.expenses,
                  ),
                  CustomNavItem(
                    label: s.navMore,
                    icon: Icons.more_horiz,
                    activeIcon: Icons.more_horiz,
                    tourTarget: TourTarget.settings,
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
          Positioned.fill(child: TourOverlay(currentBranch: currentBranch)),
        ],
      ),
    );
  }
}

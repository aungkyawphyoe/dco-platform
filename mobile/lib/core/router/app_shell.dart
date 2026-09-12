import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/custom_floating_nav_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final items = [
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

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CustomFloatingNavBar(
                currentIndex: navigationShell.currentIndex,
                items: items,
                onTap: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
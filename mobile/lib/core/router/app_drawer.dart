import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final entitlements = ref.watch(entitlementsProvider).valueOrNull;
    final showFleet = entitlements?.canUseFleet ?? false;

    return Drawer(
      backgroundColor: tokens.background.primary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keep the header fixed at the top
            _DrawerHeader(
              displayName: user?.displayName ?? user?.email ?? '',
              email: user?.email ?? '',
            ),
            Divider(height: 1, color: tokens.border.divider),

            // 1. Wrap the scrollable middle content inside an Expanded + SingleChildScrollView
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: tokens.space.s2),

                    // Quick Access
                    _SectionLabel(label: s.drawerQuickAccess),
                    _DrawerTile(
                      icon: Icons.sync,
                      title: s.drawerSync,
                      onTap: () => _navigate(context, AppRoutes.sync),
                    ),

                    Divider(height: 1, color: tokens.border.divider),
                    SizedBox(height: tokens.space.s2),

                    // Features
                    _SectionLabel(label: s.drawerFeatures),
                    _DrawerTile(
                      icon: Icons.directions_car_outlined,
                      title: s.garageMyGarage,
                      onTap: () => _navigate(context, AppRoutes.garage),
                    ),
                    _DrawerTile(
                      icon: Icons.checklist_outlined,
                      title: s.drawerMaintenancePlan,
                      onTap: () =>
                          _navigate(context, AppRoutes.maintenancePlan),
                    ),
                    _DrawerTile(
                      icon: Icons.settings_input_component_outlined,
                      title: s.drawerParts,
                      onTap: () => _navigate(context, AppRoutes.parts),
                    ),
                    _DrawerTile(
                      icon: Icons.folder_outlined,
                      title: s.drawerDocuments,
                      onTap: () => _navigate(context, AppRoutes.documents),
                    ),

                    // _DrawerTile(
                    //   icon: Icons.shield_outlined,
                    //   title: s.drawerInsurance,
                    //   onTap: () => _navigate(context, AppRoutes.insurance),
                    // ),
                    Divider(height: 1, color: tokens.border.divider),
                    SizedBox(height: tokens.space.s2),

                    // Stats
                    _SectionLabel(label: s.drawerStats),
                    _DrawerTile(
                      icon: Icons.bar_chart,
                      title: s.drawerFuelStats,
                      onTap: () => _navigate(context, AppRoutes.refuelStats),
                    ),
                    _DrawerTile(
                      icon: Icons.bar_chart,
                      title: s.drawerMaintenanceStats,
                      onTap: () =>
                          _navigate(context, AppRoutes.maintenanceStats),
                    ),
                    _DrawerTile(
                      icon: Icons.bar_chart,
                      title: s.drawerExpenseStats,
                      onTap: () => _navigate(context, AppRoutes.expenseStats),
                    ),

                    Divider(height: 1, color: tokens.border.divider),
                    SizedBox(height: tokens.space.s2),

                    // Sharing & Fleet (conditional)
                    _SectionLabel(label: s.drawerFamilyFleet),
                    _DrawerTile(
                      icon: Icons.people_outline,
                      title: s.drawerSharedWithMe,
                      onTap: () => _navigate(context, AppRoutes.sharedWithMe),
                    ),
                    _DrawerTile(
                      icon: Icons.qr_code_scanner,
                      title: s.drawerJoinShare,
                      onTap: () =>
                          _navigate(context, AppRoutes.vehicleShareJoin),
                    ),
                    // Fleet entry is presentation-only gating: the API
                    // re-checks plan, membership, org status, and role.
                    if (showFleet)
                      _DrawerTile(
                        icon: Icons.local_shipping_outlined,
                        title: s.drawerFleet,
                        onTap: () => _navigate(context, AppRoutes.fleet),
                      ),
                  ],
                ),
              ),
            ),

            // 2. The Spacer and version text sit cleanly outside the scroll view
            // to always stay anchored to the bottom.
            Divider(height: 1, color: tokens.border.divider),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.s4,
                vertical: tokens.space.s3,
              ),
              child: Text(
                'AutoHub v1.0',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.displayName, required this.email});

  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.all(tokens.space.s4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: tokens.button.primary.background,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(
                color: tokens.text.onAccent,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          SizedBox(width: tokens.space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.space.s1),
                Text(
                  email,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s4,
        vertical: tokens.space.s2,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.text.caption,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: tokens.space.s4),
      leading: Icon(icon, color: tokens.icon.inactive, size: 22),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: tokens.text.primary),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
    );
  }
}

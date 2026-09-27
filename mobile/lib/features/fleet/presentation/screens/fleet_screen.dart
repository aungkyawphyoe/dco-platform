import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Fleet hub — drawer entry point. Org card, mode switch, and the
/// admin/manager manage entries (FRD fleet-management §18).
class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  Future<void> _selectMode(
    BuildContext context,
    WidgetRef ref,
    FleetMode target,
  ) async {
    await ref.read(storedFleetModeProvider.notifier).setMode(target);
    if (context.mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final entitlementsAsync = ref.watch(entitlementsProvider);
    final orgAsync = ref.watch(myOrganizationProvider);
    final mode = ref.watch(fleetModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetTitle)),
      body: entitlementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
          actionLabel: s.retry,
          onAction: () => ref.invalidate(entitlementsProvider),
        ),
        data: (entitlements) {
          if (!entitlements.canUseFleet || entitlements.organization == null) {
            return DcoEmptyState(
              title: s.fleetNoAccessTitle,
              body: s.fleetNoAccessBody,
            );
          }
          final orgCtx = entitlements.organization!;
          final org = orgAsync.valueOrNull?.organization;
          final isDriver = orgCtx.isDriver;
          final canOperate = orgCtx.canOperate;
          final availableModes = isDriver
              ? const [FleetMode.personal, FleetMode.driver]
              : const [FleetMode.personal, FleetMode.fleet];

          return ListView(
            padding: EdgeInsets.all(tokens.space.s3),
            children: [
              // ── Organization card ──
              Card(
                child: Padding(
                  padding: EdgeInsets.all(tokens.space.s3),
                  child: orgAsync.isLoading && org == null
                      ? Text(
                          '…',
                          style: Theme.of(context).textTheme.titleLarge,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  color: tokens.icon.inactive,
                                ),
                                SizedBox(width: tokens.space.s2),
                                Expanded(
                                  child: Text(
                                    (org?.name.isNotEmpty ?? false)
                                        ? org!.name
                                        : orgCtx.id,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                StatusChip(
                                  label: fleetOrgStatusLabel(
                                    s,
                                    org?.status ?? orgCtx.status,
                                  ),
                                  tone: orgStatusTone(
                                    org?.status ?? orgCtx.status,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: tokens.space.s2),
                            Wrap(
                              spacing: tokens.space.s2,
                              runSpacing: tokens.space.s2,
                              children: [
                                StatusChip(
                                  label: fleetRoleLabel(s, orgCtx.role),
                                  tone: 'info',
                                ),
                                if (org?.contactEmail != null)
                                  Text(
                                    '${s.fleetHubOrgContact}: ${org!.contactEmail}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: tokens.text.caption,
                                        ),
                                  ),
                                if (org?.contactPhone != null)
                                  Text(
                                    org!.contactPhone!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: tokens.text.caption,
                                        ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),

              // ── Mode switch ──
              SectionHeader(s.fleetHubModeSection),
              for (final option in availableModes)
                _ModeTile(
                  selected: mode == option,
                  title: switch (option) {
                    FleetMode.personal => s.fleetModePersonalTitle,
                    FleetMode.fleet => s.fleetModeFleetTitle,
                    FleetMode.driver => s.fleetModeDriverTitle,
                  },
                  body: switch (option) {
                    FleetMode.personal => s.fleetModePersonalBody,
                    FleetMode.fleet => s.fleetModeFleetBody,
                    FleetMode.driver => s.fleetModeDriverBody,
                  },
                  icon: switch (option) {
                    FleetMode.personal => Icons.home_outlined,
                    FleetMode.fleet => Icons.local_shipping_outlined,
                    FleetMode.driver => Icons.drive_eta_outlined,
                  },
                  onTap: () => _selectMode(context, ref, option),
                ),

              // ── Manage (admin / manager) ──
              if (!isDriver) ...[
                SectionHeader(s.fleetHubManageSection),
                if (orgCtx.canManageOrg)
                  FleetTile(
                    title: s.fleetHubOrgManagement,
                    subtitle: org?.name,
                    icon: Icons.apartment_outlined,
                    onTap: () => context.push(AppRoutes.fleetOrg),
                  ),
                if (canOperate) ...[
                  FleetTile(
                    title: s.fleetHubAssignments,
                    icon: Icons.assignment_ind_outlined,
                    onTap: () => context.push(AppRoutes.fleetAssignments),
                  ),
                  FleetTile(
                    title: s.fleetHubWarrantyTemplates,
                    icon: Icons.verified_outlined,
                    onTap: () =>
                        context.push(AppRoutes.fleetWarrantyTemplates),
                  ),
                ],
              ],
              SizedBox(height: tokens.space.s5),
            ],
          );
        },
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.selected,
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Card(
      margin: EdgeInsets.only(bottom: tokens.space.s2),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? tokens.icon.active : tokens.icon.inactive,
        ),
        title: Text(title),
        subtitle: Text(
          body,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: tokens.icon.active)
            : null,
        onTap: onTap,
      ),
    );
  }
}

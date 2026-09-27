import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `GET /organizations/:id/members` — role change and removal for admins.
class OrgMembersTab extends ConsumerWidget {
  const OrgMembersTab({
    super.key,
    required this.orgId,
    required this.canManage,
  });

  final String orgId;
  final bool canManage;

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String currentRole,
  ) async {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var value = currentRole;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(s.fleetOrgChangeRole),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final role in const [
                  'org_admin',
                  'org_manager',
                  'org_mechanic',
                  'org_driver',
                ])
                  ListTile(
                    dense: true,
                    title: Text(fleetRoleLabel(s, role)),
                    trailing: value == role
                        ? Icon(Icons.check, color: tokens.text.accent)
                        : null,
                    onTap: () => setDialogState(() => value = role),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, value),
                child: Text(s.save),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == currentRole) return;
    try {
      await ref
          .read(fleetRepositoryProvider)
          .updateMemberRole(orgId, userId, selected);
      ref.invalidate(orgMembersProvider(orgId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.fleetOrgRemoveConfirmTitle),
        content: Text(s.fleetOrgRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.fleetOrgRemoveMember),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(fleetRepositoryProvider).removeMember(orgId, userId);
      ref.invalidate(orgMembersProvider(orgId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final membersAsync = ref.watch(orgMembersProvider(orgId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => error is FleetAccessDenied
          ? DcoEmptyState(
              title: s.fleetOrgNotPermitted,
              body: s.fleetOrgNotPermittedBody,
            )
          : DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(orgMembersProvider(orgId)),
            ),
      data: (members) {
        if (members.isEmpty) {
          return DcoEmptyState(
            title: s.fleetOrgMembersEmpty,
            body: s.fleetOrgMembersEmpty,
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(tokens.space.s3),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return Card(
              margin: EdgeInsets.only(bottom: tokens.space.s2),
              child: ListTile(
                leading: Icon(
                  member.isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: tokens.icon.inactive,
                ),
                title: Text(member.label),
                subtitle: Text(
                  member.email,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                ),
                trailing: StatusChip(
                  label: fleetRoleLabel(s, member.role),
                  tone: member.isAdmin ? 'warning' : 'info',
                ),
                onTap: !canManage
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        builder: (sheetContext) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.swap_horiz),
                                title: Text(s.fleetOrgChangeRole),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _changeRole(
                                    context,
                                    ref,
                                    member.userId,
                                    member.role,
                                  );
                                },
                              ),
                              ListTile(
                                leading: Icon(
                                  Icons.person_remove,
                                  color: tokens.status.dangerFg,
                                ),
                                title: Text(
                                  s.fleetOrgRemoveMember,
                                  style: TextStyle(
                                    color: tokens.status.dangerFg,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _removeMember(context, ref, member.userId);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

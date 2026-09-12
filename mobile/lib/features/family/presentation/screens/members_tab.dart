import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart'
    as family_entities;
import 'package:dco_mobile/features/family/presentation/widgets/family_empty_state.dart';

class MembersTab extends ConsumerWidget {
  final family_entities.Family family;
  final AsyncValue<List<family_entities.FamilyMember>> membersAsync;

  const MembersTab({super.key, required this.family, required this.membersAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final currentUserId = ref.watch(currentUserIdProvider);
    final isPrimaryOwner = family.createdBy == currentUserId;

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (members) {
        if (members.isEmpty) {
          return FamilyEmptyState(
            icon: Icons.people_outline,
            title: s.membersTabEmptyTitle,
            message: s.membersTabEmptyBody,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final member = members[index];
            final isSelf = member.userId == currentUserId;

            return _MemberTile(
              member: member,
              isSelf: isSelf,
              isPrimaryOwner: isPrimaryOwner,
              canManage: isPrimaryOwner && !isSelf,
              onTap: () => context.go('/user/${member.userId}/detail'),
              onManage: isPrimaryOwner && !isSelf
                  ? () => _showManageMemberSheet(context, ref, member)
                  : null,
            );
          },
        );
      },
    );
  }

  void _showManageMemberSheet(
    BuildContext context,
    WidgetRef ref,
    family_entities.FamilyMember member,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ManageMemberSheet(member: member),
    );
  }
}

class _ManageMemberSheet extends ConsumerStatefulWidget {
  final family_entities.FamilyMember member;

  const _ManageMemberSheet({required this.member});

  @override
  ConsumerState<_ManageMemberSheet> createState() => _ManageMemberSheetState();
}

class _ManageMemberSheetState extends ConsumerState<_ManageMemberSheet> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<DcoTokens>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.membersTabManageTitle(widget.member.displayName ?? widget.member.email),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: tokens.text.primary),
            ),
            const SizedBox(height: 16),
            Text(s.membersTabRoleSection, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'member',
                  label: Text(s.membersTabRoleMember),
                  icon: const Icon(Icons.person),
                ),
                ButtonSegment(
                  value: 'driver',
                  label: Text(s.membersTabRoleDriver),
                  icon: const Icon(Icons.drive_eta),
                ),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (Set<String> selection) {
                setState(() => _selectedRole = selection.first);
              },
            ),
            const SizedBox(height: 16),
            DcoButton(
              label: s.membersTabSaveRole,
              onPressed: _selectedRole != widget.member.role
                  ? () async {
                      final repo = ref.read(familyRepositoryProvider);
                      await repo.updateMemberRole(
                        widget.member.userId,
                        _selectedRole,
                      );
                      if (mounted) Navigator.pop(context);
                      ref.invalidate(familyMembersProvider);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            DcoButton(
              label: s.membersTabRemoveButton,
              variant: DcoButtonVariant.destructive,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(s.membersTabRemoveTitle),
                    content: Text(
                      s.membersTabRemoveBody(widget.member.displayName ?? widget.member.email),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          s.membersTabRemoveAction,
                          style: TextStyle(color: tokens.status.dangerFg),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  final repo = ref.read(familyRepositoryProvider);
                  await repo.removeMember(widget.member.userId);
                  if (mounted) {
                    Navigator.pop(context);
                    ref.invalidate(familyMembersProvider);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final family_entities.FamilyMember member;
  final bool isSelf;
  final bool isPrimaryOwner;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback? onManage;

  const _MemberTile({
    required this.member,
    required this.isSelf,
    required this.isPrimaryOwner,
    required this.canManage,
    required this.onTap,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;

    Color roleColor;
    IconData roleIcon;
    switch (member.role) {
      case 'primary_owner':
        roleColor = tokens.text.accent;
        roleIcon = Icons.emoji_events;
        break;
      case 'member':
        roleColor = tokens.status.infoFg;
        roleIcon = Icons.person;
        break;
      case 'driver':
        roleColor = tokens.status.successFg;
        roleIcon = Icons.drive_eta;
        break;
      default:
        roleColor = tokens.text.tertiary;
        roleIcon = Icons.help;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.border.defaultColor),
        ),
        child: Row(
          children: [
            DcoAvatar(name: member.displayName ?? member.email, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.displayName ?? member.email,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: tokens.text.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.text.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.membersTabYouBadge,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: tokens.text.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(roleIcon, size: 12, color: roleColor),
                            const SizedBox(width: 4),
                            Text(
                              _roleLabel(member.role, AppLocalizations.of(context)!),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: roleColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (member.licenseStatus != null) ...[
                        const SizedBox(width: 8),
                        _LicenseStatusBadge(status: member.licenseStatus!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.membersTabVehicleCount(member.vehicleCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.tertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (canManage)
              IconButton(
                icon: Icon(Icons.more_vert, color: tokens.text.tertiary),
                onPressed: onManage,
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role, AppLocalizations s) {
    switch (role) {
      case 'primary_owner':
        return s.membersTabPrimaryOwner;
      case 'member':
        return s.membersTabRoleMember;
      case 'driver':
        return s.membersTabRoleDriver;
      default:
        return role;
    }
  }
}

class _LicenseStatusBadge extends StatelessWidget {
  final String status;

  const _LicenseStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;

    final s = AppLocalizations.of(context)!;
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'valid':
        color = tokens.status.successFg;
        icon = Icons.check_circle;
        label = s.membersTabLicenseValid;
        break;
      case 'expiring_soon':
        color = tokens.status.warningFg;
        icon = Icons.schedule;
        label = s.membersTabLicenseExpiringSoon;
        break;
      case 'expired':
        color = tokens.status.dangerFg;
        icon = Icons.cancel;
        label = s.membersTabLicenseExpired;
        break;
      default:
        color = tokens.text.tertiary;
        icon = Icons.help;
        label = s.membersTabLicenseNone;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

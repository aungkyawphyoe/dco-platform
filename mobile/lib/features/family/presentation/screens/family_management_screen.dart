import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart' as family_entities;

class FamilyManagementScreen extends ConsumerStatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  ConsumerState<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends ConsumerState<FamilyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final familyAsync = ref.watch(myFamilyProvider);
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: tokens.text.accent,
          unselectedLabelColor: tokens.text.tertiary,
          indicatorColor: tokens.text.accent,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Members'),
            Tab(icon: Icon(Icons.directions_car), text: 'Vehicles'),
            Tab(icon: Icon(Icons.share), text: 'Invite'),
          ],
        ),
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (family) {
          if (family == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom, size: 64, color: tokens.text.tertiary),
                  const SizedBox(height: 16),
                  Text('No family yet', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  DcoButton(
                    label: 'Create Family',
                    onPressed: () => context.go('/settings/family/create'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _MembersTab(family: family, membersAsync: membersAsync),
              _VehiclesTab(family: family),
              _InviteTab(family: family),
            ],
          );
        },
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  final family_entities.Family family;
  final AsyncValue<List<family_entities.FamilyMember>> membersAsync;

  const _MembersTab({required this.family, required this.membersAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final currentUserId = ref.watch(currentUserIdProvider);
    final isPrimaryOwner = family.createdBy == currentUserId;

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (members) {
        if (members.isEmpty) {
          return _EmptyState(
            icon: Icons.people_outline,
            title: 'No members yet',
            message: 'Invite family to get started.',
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
              onTap: () => _showMemberDetails(context, ref, member),
              onManage: isPrimaryOwner && !isSelf
                  ? () => _showManageMemberSheet(context, ref, member)
                  : null,
            );
          },
        );
      },
    );
  }

  void _showMemberDetails(BuildContext context, WidgetRef ref, family_entities.FamilyMember member) {
    context.go('/user/${member.userId}/detail');
  }

  void _showManageMemberSheet(BuildContext context, WidgetRef ref, family_entities.FamilyMember member) {
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
    final tokens = Theme.of(context).extension<DcoTokens>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Manage ${widget.member.displayName ?? widget.member.email}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: tokens.text.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Text('Role', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'member', label: Text('Member'), icon: Icon(Icons.person)),
                ButtonSegment(value: 'driver', label: Text('Driver'), icon: Icon(Icons.drive_eta)),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (Set<String> selection) {
                setState(() => _selectedRole = selection.first);
              },
            ),
            const SizedBox(height: 16),
            DcoButton(
              label: 'Save Role',
              onPressed: _selectedRole != widget.member.role
                  ? () async {
                      final repo = ref.read(familyRepositoryProvider);
                      await repo.updateMemberRole(widget.member.userId, _selectedRole);
                      if (mounted) Navigator.pop(context);
                      ref.invalidate(familyMembersProvider);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            DcoButton(
              label: 'Remove from Family',
              variant: DcoButtonVariant.destructive,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Member?'),
                    content: Text('Remove ${widget.member.displayName ?? widget.member.email} from the family?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: TextStyle(color: tokens.status.dangerFg))),
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

class _VehiclesTab extends ConsumerWidget {
  final family_entities.Family family;

  const _VehiclesTab({required this.family});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;

    return _EmptyState(
      icon: Icons.directions_car_outlined,
      title: 'No vehicles in family',
      message: 'Vehicles will appear here when members add them.',
    );
  }
}

class _InviteTab extends ConsumerStatefulWidget {
  final family_entities.Family family;

  const _InviteTab({required this.family});

  @override
  ConsumerState<_InviteTab> createState() => _InviteTabState();
}

class _InviteTabState extends ConsumerState<_InviteTab> {
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final family = widget.family;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share Your Family',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: tokens.text.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Invite family members to join and share vehicles.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.secondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border.defaultColor),
            ),
            child: Column(
              children: [
                Text(
                  'Share Code',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tokens.text.tertiary,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  family.shareCode,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: tokens.text.accent,
                        fontFamily: 'IBM Plex Mono',
                        letterSpacing: 4,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: 'dco://family/join?code=${family.shareCode}',
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan with DCO app to join',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.tertiary,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DcoButton(
                        label: 'Copy Code',
                        variant: DcoButtonVariant.secondary,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DcoButton(
                        label: 'Share',
                        onPressed: () => SharePlus.instance.share(ShareParams(text: 'Join my DCO family! Code: ${family.shareCode}')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DcoButton(
                  label: 'Regenerate Code',
                  variant: DcoButtonVariant.tertiary,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Regenerate Share Code?'),
                        content: const Text('This will invalidate the current code. Members with the old code won\'t be able to join.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Regenerate')),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      final repo = ref.read(familyRepositoryProvider);
                      await repo.updateFamily(regenerateShareCode: true);
                      if (mounted) ref.invalidate(myFamilyProvider);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Code expires in 7 days. Regenerating invalidates the old code.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.text.tertiary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: tokens.text.primary,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.text.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                              _roleLabel(member.role),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    '${member.vehicleCount} vehicle${member.vehicleCount == 1 ? '' : 's'}',
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

  String _roleLabel(String role) {
    switch (role) {
      case 'primary_owner':
        return 'Primary Owner';
      case 'member':
        return 'Member';
      case 'driver':
        return 'Driver';
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

    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'valid':
        color = tokens.status.successFg;
        icon = Icons.check_circle;
        label = 'Valid';
        break;
      case 'expiring_soon':
        color = tokens.status.warningFg;
        icon = Icons.schedule;
        label = 'Expiring Soon';
        break;
      case 'expired':
        color = tokens.status.dangerFg;
        icon = Icons.cancel;
        label = 'Expired';
        break;
      default:
        color = tokens.text.tertiary;
        icon = Icons.help;
        label = 'No License';
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: tokens.text.tertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.text.secondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.text.tertiary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

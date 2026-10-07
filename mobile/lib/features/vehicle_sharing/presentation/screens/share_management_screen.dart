import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/vehicle_share.dart';
import '../../domain/repositories/vehicle_share_repository.dart';
import '../../providers.dart';
import '../widgets/share_access_level.dart';
import '../widgets/share_code_panel.dart';

/// Owner's per-vehicle sharing console: who has access, what is still
/// pending, and the share code/QR.
class ShareManagementScreen extends ConsumerStatefulWidget {
  const ShareManagementScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<ShareManagementScreen> createState() =>
      _ShareManagementScreenState();
}

class _ShareManagementScreenState extends ConsumerState<ShareManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _busy = false;

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

  VehicleShareRepository get _repo => ref.read(vehicleShareRepositoryProvider);

  void _refresh() => ref.invalidate(vehicleSharesProvider(widget.vehicleId));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAccess(VehicleShare share) async {
    final s = AppLocalizations.of(context)!;
    final selected = await showDialog<ShareAccessLevel>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.shareChangeAccess),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final level in ShareAccessLevel.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(switch (level) {
                  ShareAccessLevel.view => s.shareAccessView,
                  ShareAccessLevel.addEditOwn => s.shareAccessAddEditOwn,
                }),
                trailing: level == share.accessLevel
                    ? Icon(Icons.check, color: context.tokens.icon.active)
                    : null,
                onTap: () => Navigator.pop(context, level),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (selected == null || selected == share.accessLevel) return;
    await _run(
      () => _repo.updateShare(
        vehicleId: widget.vehicleId,
        shareId: share.id,
        accessLevel: selected,
      ),
    );
  }

  Future<void> _revoke(VehicleShare share) async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.shareRevokeTitle),
        content: Text(s.shareRevokeBody(share.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              s.shareRevokeAction,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _repo.revokeShare(vehicleId: widget.vehicleId, shareId: share.id),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.shareRevoked)));
  }

  Future<void> _resend(ShareInvitation invite) async {
    final s = AppLocalizations.of(context)!;
    await _run(
      () => _repo.resendInvite(vehicleId: widget.vehicleId, invitation: invite),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.shareInviteResent)));
  }

  Future<void> _cancelInvite(ShareInvitation invite) async {
    final s = AppLocalizations.of(context)!;
    await _run(
      () => _repo.cancelInvite(vehicleId: widget.vehicleId, invitation: invite),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.shareInviteCancelled)));
  }

  Future<void> _regenerateCode() async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.shareRegenerateTitle),
        content: Text(s.shareRegenerateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.shareRegenerateAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _repo.createShare(
        vehicleId: widget.vehicleId,
        method: ShareMethod.codeQr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final sharesAsync = ref.watch(vehicleSharesProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(title: Text(s.shareManagementTitle), actions: [
        ],
      ),
      body: sharesAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            _buildHeaderSliver(context, null),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (error, _) => CustomScrollView(
          slivers: [
            _buildHeaderSliver(context, null),
            SliverFillRemaining(
              child: DcoEmptyState(
                title: s.error,
                body: error.toString(),
                actionLabel: s.retry,
                onAction: _refresh,
              ),
            ),
          ],
        ),
        data: (detail) {
          if (detail == null) {
            return CustomScrollView(
              slivers: [
                _buildHeaderSliver(context, null),
                SliverFillRemaining(
                  child: DcoEmptyState(
                    title: s.shareOwnerOnly,
                    body: s.error,
                    actionLabel: s.retry,
                    onAction: _refresh,
                  ),
                ),
              ],
            );
          }
          return CustomScrollView(
            slivers: [
              _buildHeaderSliver(context, detail),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  controller: _tabController,
                  tokens: tokens,
                  s: s,
                ),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ActiveTab(
                      detail: detail,
                      busy: _busy,
                      onChangeAccess: _changeAccess,
                      onRevoke: _revoke,
                    ),
                    _PendingTab(
                      detail: detail,
                      busy: _busy,
                      onResend: _resend,
                      onCancel: _cancelInvite,
                    ),
                    ShareCodePanel(
                      detail: detail,
                      loading: _busy,
                      onGenerate: _regenerateCode,
                      onRegenerate: _regenerateCode,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderSliver(BuildContext context, VehicleSharesDetail? detail) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicleName = detail?.vehicleName.isNotEmpty == true
        ? detail!.vehicleName
        : s.shareVehicleTitle;
    final licensePlate = detail?.licensePlate ?? '';
    final activeCount = detail?.limits.activeOnVehicle ?? 0;
    final perVehicleLimit = detail?.limits.perVehicle ?? 0;

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          tokens.space.s4,
          tokens.space.s4,
          tokens.space.s4,
          tokens.space.s3,
        ),
        color: tokens.background.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicleName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: tokens.text.primary),
            ),
            SizedBox(height: tokens.space.s1),
            Text(
              licensePlate,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.text.secondary,
                fontFamily: 'IBM Plex Mono',
              ),
            ),
            SizedBox(height: tokens.space.s2),
            Text(
              s.shareLimits(activeCount, perVehicleLimit),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTab extends StatelessWidget {
  const _ActiveTab({
    required this.detail,
    required this.busy,
    required this.onChangeAccess,
    required this.onRevoke,
  });

  final VehicleSharesDetail detail;
  final bool busy;
  final ValueChanged<VehicleShare> onChangeAccess;
  final ValueChanged<VehicleShare> onRevoke;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final items = detail.activeShares;

    if (items.isEmpty) {
      return DcoEmptyState(
        title: s.shareActiveEmpty,
        body: s.shareActiveEmptyBody,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        tokens.space.s1,
        tokens.space.s3,
        tokens.space.s1,
        tokens.space.s3,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.space.s2),
      itemBuilder: (context, index) {
        final share = items[index];
        final List<Widget> children = <Widget>[
          Row(
            children: [
              Flexible(
                child: Text(
                  share.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.tokens.text.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.tokens.space.s2),
              ShareAccessBadge(accessLevel: share.accessLevel),
            ],
          ),
        ];
        if (share.email != null) {
          children.add(SizedBox(height: context.tokens.space.s1));
          children.add(
            Text(
              share.email!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.tokens.text.secondary,
              ),
            ),
          );
        }
        children.add(SizedBox(height: context.tokens.space.s1));
        children.add(
          Text(
            AppLocalizations.of(context)!.shareJoinedOn(
              DateFormat.yMMMd().format(share.acceptedAt ?? share.createdAt),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.tokens.text.tertiary,
            ),
          ),
        );
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: context.tokens.space.s4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.tokens.radius.lg),
              boxShadow: context.tokens.shadows.card,
            ),
            child: Material(
              color: context.tokens.background.card,
              borderRadius: BorderRadius.circular(context.tokens.radius.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(context.tokens.radius.lg),
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.all(context.tokens.space.s3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children,
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !busy,
                        icon: Icon(
                          Icons.more_vert,
                          color: context.tokens.icon.inactive,
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'access':
                              onChangeAccess(share);
                            case 'revoke':
                              onRevoke(share);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'access',
                            child: Text(
                              AppLocalizations.of(context)!.shareChangeAccess,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'revoke',
                            child: Text(
                              AppLocalizations.of(context)!.shareRevoke,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PendingTab extends StatelessWidget {
  const _PendingTab({
    required this.detail,
    required this.busy,
    required this.onResend,
    required this.onCancel,
  });

  final VehicleSharesDetail detail;
  final bool busy;
  final ValueChanged<ShareInvitation> onResend;
  final ValueChanged<ShareInvitation> onCancel;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    // Code/QR invitations have no addressee — they live on the Code tab.
    final items = detail.pendingInvites
        .where((invite) => invite.invitedEmail != null)
        .toList();

    if (items.isEmpty) {
      return DcoEmptyState(
        title: s.sharePendingEmpty,
        body: s.sharePendingEmptyBody,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        tokens.space.s1,
        tokens.space.s3,
        tokens.space.s1,
        tokens.space.s3,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.space.s2),
      itemBuilder: (context, index) {
        final invite = items[index];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space.s4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              boxShadow: tokens.shadows.card,
            ),
            child: Material(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              child: Padding(
                padding: EdgeInsets.all(tokens.space.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            invite.invitedEmail ?? '',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: tokens.text.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ShareAccessBadge(accessLevel: invite.accessLevel),
                      ],
                    ),
                    SizedBox(height: tokens.space.s1),
                    Text(
                      invite.isExpired
                          ? s.shareExpiresOn(
                              DateFormat.yMMMd().format(invite.expiresAt),
                            )
                          : s.sharePendingSince(
                              DateFormat.yMMMd().format(invite.createdAt),
                            ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.tertiary,
                      ),
                    ),
                    SizedBox(height: tokens.space.s2),
                    Row(
                      children: [
                        Expanded(
                          child: DcoButton(
                            label: s.shareResend,
                            variant: DcoButtonVariant.secondary,
                            loading: busy,
                            onPressed: () => onResend(invite),
                          ),
                        ),
                        SizedBox(width: tokens.space.s2),
                        Expanded(
                          child: DcoButton(
                            label: s.shareCancelInvite,
                            variant: DcoButtonVariant.destructive,
                            loading: busy,
                            onPressed: () => onCancel(invite),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({
    required this.controller,
    required this.tokens,
    required this.s,
  });

  final TabController controller;
  final DcoTokens tokens;
  final AppLocalizations s;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: tokens.background.primary,
      child: TabBar(
        controller: controller,
        labelColor: tokens.text.accent,
        unselectedLabelColor: tokens.text.tertiary,
        indicatorColor: tokens.text.accent,
        tabs: [
          Tab(icon: const Icon(Icons.people_outline), text: s.shareTabActive),
          Tab(icon: const Icon(Icons.mail_outline), text: s.shareTabPending),
          Tab(icon: const Icon(Icons.qr_code), text: s.shareTabCode),
        ],
      ),
    );
  }

  @override
  double get maxExtent => kToolbarHeight;

  @override
  double get minExtent => kToolbarHeight;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.tokens != tokens ||
        oldDelegate.s != s;
  }
}

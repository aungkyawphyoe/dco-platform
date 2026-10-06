import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../core/router/routes.dart';
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

class _ShareManagementScreenState
    extends ConsumerState<ShareManagementScreen>
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

  VehicleShareRepository get _repo =>
      ref.read(vehicleShareRepositoryProvider);

  void _refresh() =>
      ref.invalidate(vehicleSharesProvider(widget.vehicleId));

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
                title: Text(
                  switch (level) {
                    ShareAccessLevel.view => s.shareAccessView,
                    ShareAccessLevel.addEditOwn => s.shareAccessAddEditOwn,
                  },
                ),
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
      () => _repo.revokeShare(
        vehicleId: widget.vehicleId,
        shareId: share.id,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.shareRevoked)),
    );
  }

  Future<void> _resend(ShareInvitation invite) async {
    final s = AppLocalizations.of(context)!;
    await _run(
      () => _repo.resendInvite(
        vehicleId: widget.vehicleId,
        invitation: invite,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.shareInviteResent)),
    );
  }

  Future<void> _cancelInvite(ShareInvitation invite) async {
    final s = AppLocalizations.of(context)!;
    await _run(
      () => _repo.cancelInvite(
        vehicleId: widget.vehicleId,
        invitation: invite,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.shareInviteCancelled)),
    );
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
      appBar: AppBar(
        title: Text(s.shareManagementTitle),
        actions: [
          IconButton(
            tooltip: s.shareSendInvite,
            icon: Icon(Icons.person_add_alt_1_outlined, color: tokens.icon.active),
            onPressed: () => context.push(
              AppRoutes.vehicleShareNew(widget.vehicleId),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: tokens.text.accent,
          unselectedLabelColor: tokens.text.tertiary,
          indicatorColor: tokens.text.accent,
          tabs: [
            Tab(icon: const Icon(Icons.people_outline), text: s.shareTabActive),
            Tab(
              icon: const Icon(Icons.mail_outline),
              text: s.shareTabPending,
            ),
            Tab(icon: const Icon(Icons.qr_code), text: s.shareTabCode),
          ],
        ),
      ),
      body: sharesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: _refresh,
        ),
        data: (detail) {
          if (detail == null) {
            return DcoEmptyState(
              title: s.shareOwnerOnly,
              body: s.error,
              actionLabel: s.retry,
              onAction: _refresh,
            );
          }
          return Column(
            children: [
              _Header(detail: detail),
              Expanded(
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
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final VehicleSharesDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.space.s3),
      color: tokens.background.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.vehicleName.isEmpty ? s.shareVehicleTitle : detail.vehicleName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: tokens.text.primary),
          ),
          SizedBox(height: tokens.space.s1),
          Text(
            detail.licensePlate,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.text.secondary,
              fontFamily: 'IBM Plex Mono',
            ),
          ),
          SizedBox(height: tokens.space.s2),
          Text(
            s.shareLimits(
              detail.limits.activeOnVehicle,
              detail.limits.perVehicle,
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
          ),
        ],
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
      padding: EdgeInsets.all(tokens.space.s4),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.space.s2),
      itemBuilder: (context, index) {
        final share = items[index];
        final joined = share.acceptedAt ?? share.createdAt;
        return Container(
          padding: EdgeInsets.all(tokens.space.s3),
          decoration: BoxDecoration(
            color: tokens.background.card,
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(color: tokens.border.defaultColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            share.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: tokens.text.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: tokens.space.s2),
                        ShareAccessBadge(accessLevel: share.accessLevel),
                      ],
                    ),
                    if (share.email != null) ...[
                      SizedBox(height: tokens.space.s1),
                      Text(
                        share.email!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.text.secondary),
                      ),
                    ],
                    SizedBox(height: tokens.space.s1),
                    Text(
                      s.shareJoinedOn(DateFormat.yMMMd().format(joined)),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.text.tertiary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: !busy,
                icon: Icon(Icons.more_vert, color: tokens.icon.inactive),
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
                    child: Text(s.shareChangeAccess),
                  ),
                  PopupMenuItem(value: 'revoke', child: Text(s.shareRevoke)),
                ],
              ),
            ],
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
      padding: EdgeInsets.all(tokens.space.s4),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.space.s2),
      itemBuilder: (context, index) {
        final invite = items[index];
        return Container(
          padding: EdgeInsets.all(tokens.space.s3),
          decoration: BoxDecoration(
            color: tokens.background.card,
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(color: tokens.border.defaultColor),
          ),
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
                    : s.sharePendingSince(DateFormat.yMMMd().format(invite.createdAt)),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
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
        );
      },
    );
  }
}

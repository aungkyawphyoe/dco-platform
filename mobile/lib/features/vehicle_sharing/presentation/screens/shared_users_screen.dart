import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_avatar.dart';
import '../../../../core/widgets/dco_card.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../generated/app_localizations.dart';
import '../../../pricing/providers.dart';
import '../../domain/entities/vehicle_share.dart';
import '../../providers.dart';

class SharedUsersScreen extends ConsumerStatefulWidget {
  const SharedUsersScreen({super.key});
  @override
  ConsumerState<SharedUsersScreen> createState() => _SharedUsersScreenState();
}

class _SharedUsersScreenState extends ConsumerState<SharedUsersScreen> {
  bool _refreshing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    if (!mounted ||
        _refreshing ||
        ref.read(driverOrganizationIdProvider) != null) {
      return;
    }
    setState(() {
      _refreshing = true;
      _failed = false;
    });
    // Pricing can fail independently: never hide cached sharing data for it.
    final pricing = ref
        .read(pricingRepositoryProvider)
        .refresh()
        .catchError((_) {});
    try {
      await ref.read(sharedUsersRepositoryProvider).refresh();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    await pricing;
  }

  Future<void> _manage(String vehicleId) async {
    await context.push(AppRoutes.vehicleShareManage(vehicleId));
    if (mounted) await _refresh();
  }

  String _access(ShareAccessLevel level, AppLocalizations s) =>
      level == ShareAccessLevel.view
      ? s.shareAccessView
      : s.shareAccessAddEditOwn;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    if (ref.watch(driverOrganizationIdProvider) != null) {
      return const SizedBox.shrink();
    }
    final overview = ref.watch(sharedUsersOverviewProvider);
    final plans = ref.watch(pricingPlansProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.sharedUsersTitle),
        actions: [
          IconButton(
            tooltip: s.retry,
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => DcoEmptyState(
          title: s.error,
          body: s.shareErrorGeneric,
          actionLabel: s.retry,
          onAction: () {
            ref.invalidate(sharedUsersOverviewProvider);
            _refresh();
          },
        ),
        data: (data) {
          if (data == null) {
            if (!_failed) {
              return const Center(child: CircularProgressIndicator());
            }
            return DcoEmptyState(
              title: s.error,
              body: s.sharedUsersLoadError,
              actionLabel: s.retry,
              onAction: _refresh,
            );
          }
          final people = data.people.values.toList();
          final pending = [
            for (final vehicle in data.vehicles)
              for (final invite in vehicle.pendingInvites)
                if (invite.acceptedAt == null) (vehicle, invite),
          ];
          final canUpgrade =
              data.limit != null &&
              (plans?.any(
                    (plan) =>
                        plan.sharing == null || plan.sharing! > data.limit!,
                  ) ??
                  false);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                if (canUpgrade) ...[
                  DcoCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: Text(s.sharedUsersUpgradeTitle),
                      subtitle: Text(s.sharedUsersUpgradeBody),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await context.push(AppRoutes.pricing);
                        if (mounted) await _refresh();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_refreshing) const LinearProgressIndicator(),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      s.sharedUsersCached,
                      style: TextStyle(color: tokens.text.caption),
                    ),
                  ),
                DcoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.sharedUsersUsed(data.used),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.remaining == null
                            ? s.sharedUsersUnlimited
                            : s.sharedUsersRemaining(data.remaining!),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.sharedUsersQuotaHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.sharedUsersUpdated(
                          DateFormat.yMd(
                            s.localeName,
                          ).add_jm().format(data.updatedAt.toLocal()),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (people.isEmpty)
                  DcoCard(
                    child: Column(
                      children: [
                        Text(
                          s.shareActiveEmpty,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(s.sharedUsersEmptyBody),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.garage),
                          child: Text(s.garageMyGarage),
                        ),
                      ],
                    ),
                  ),
                for (final shares in people)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DcoCard(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        key: PageStorageKey(shares.first.share.userId),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: DcoAvatar(
                          name: shares.first.share.label,
                          radius: 20,
                        ),
                        title: Text(shares.first.share.label),
                        subtitle: Text(
                          s.sharedUsersVehicleCount(shares.length),
                        ),
                        children: [
                          for (final entry in shares)
                            ListTile(
                              title: Text(entry.vehicle.vehicleName),
                              subtitle: Text(
                                '${entry.vehicle.licensePlate} · ${_access(entry.share.accessLevel, s)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _manage(entry.vehicle.vehicleId),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  s.sharedUsersPending,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty) Text(s.sharePendingEmpty),
                if (pending.isNotEmpty)
                  DcoCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (vehicle, invite) in pending)
                          ListTile(
                            title: Text(invite.invitedEmail ?? s.shareCodeTab),
                            subtitle: Text(
                              '${vehicle.vehicleName} · ${vehicle.licensePlate}\n${invite.isExpired ? s.sharedUsersExpired : s.shareTabPending} · ${_access(invite.accessLevel, s)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _manage(vehicle.vehicleId),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final syncState =
        ref.watch(syncStatusProvider).valueOrNull ?? const SyncState();
    final isSyncing = syncState.phase == SyncPhase.syncing;
    final autoSyncEnabled = ref.watch(autoSyncProvider);
    final pendingCount = ref.watch(pendingOutboxCountProvider);
    final connectivity = ref.watch(connectivityProvider);
    final isOnline =
        connectivity.valueOrNull?.any((r) => r != ConnectivityResult.none) ??
        true;

    return Scaffold(
      appBar: AppBar(title: Text(s.syncStatusTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s4),
        children: [
          // -- Hero status card
          _StatusHeroCard(
            syncState: syncState,
            isSyncing: isSyncing,
            isOnline: isOnline,
            tokens: tokens,
            s: s,
          ),
          SizedBox(height: tokens.space.s4),

          // -- Auto-sync toggle
          _InfoCard(
            tokens: tokens,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.text.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                  ),
                  child: Icon(
                    Icons.autorenew,
                    color: autoSyncEnabled
                        ? tokens.text.accent
                        : tokens.icon.inactive,
                    size: 22,
                  ),
                ),
                SizedBox(width: tokens.space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.syncAutoSync,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: tokens.space.s1),
                      Text(
                        s.syncAutoSyncDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: autoSyncEnabled,
                  onChanged: (_) {
                    ref.read(autoSyncProvider.notifier).toggle();
                  },
                  activeThumbColor: tokens.text.accent,
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.space.s3),

          // -- Pending items
          _PendingCard(pendingCount: pendingCount, tokens: tokens, s: s),
          SizedBox(height: tokens.space.s3),

          // -- Sync now button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.button.primary.background,
                foregroundColor: tokens.text.inverse,
              ),
              onPressed: isSyncing
                  ? null
                  : () async {
                      await ref.read(syncEngineProvider).syncNow();
                      ref.invalidate(pendingOutboxCountProvider);
                    },
              icon: isSyncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.text.onAccent,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                isSyncing ? s.settingsSyncStatusSyncing : s.syncManualSync,
              ),
            ),
          ),
          SizedBox(height: tokens.space.s4),

          // -- How it works
          _HowItWorksCard(tokens: tokens, s: s),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status hero card
// ---------------------------------------------------------------------------

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({
    required this.syncState,
    required this.isSyncing,
    required this.isOnline,
    required this.tokens,
    required this.s,
  });

  final SyncState syncState;
  final bool isSyncing;
  final bool isOnline;
  final DcoTokens tokens;
  final AppLocalizations s;

  @override
  Widget build(BuildContext context) {
    final hasError = syncState.hasError;
    final accentColor = hasError
        ? tokens.status.dangerFg
        : isSyncing
        ? tokens.text.accent
        : tokens.status.successFg;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        boxShadow: tokens.shadows.card,
      ),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s5),
          child: Column(
            children: [
              // Animated icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isSyncing
                      ? SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: tokens.text.accent,
                          ),
                        )
                      : Icon(
                          hasError
                              ? Icons.error_outline_rounded
                              : isOnline
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          color: accentColor,
                          size: 32,
                        ),
                ),
              ),
              SizedBox(height: tokens.space.s3),

              // Status text
              Text(
                _heroTitle(s),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.space.s1),
              Text(
                _heroSubtitle(s),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasError
                      ? tokens.status.dangerFg
                      : tokens.text.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.space.s3),

              // Connectivity + last synced chips
              Wrap(
                spacing: tokens.space.s2,
                runSpacing: tokens.space.s2,
                alignment: WrapAlignment.center,
                children: [
                  _StatusChip(
                    icon: isOnline ? Icons.wifi : Icons.wifi_off,
                    label: isOnline
                        ? s.syncStatusConnected
                        : s.syncStatusOffline,
                    color: isOnline
                        ? tokens.status.successFg
                        : tokens.status.warningFg,
                    tokens: tokens,
                  ),
                  _StatusChip(
                    icon: Icons.access_time,
                    label: syncState.lastSyncedAt != null
                        ? _formatLastSynced(syncState.lastSyncedAt!, s)
                        : s.syncNever,
                    color: tokens.text.secondary,
                    tokens: tokens,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _heroTitle(AppLocalizations s) {
    if (isSyncing) return s.settingsSyncStatusSyncing;
    if (syncState.hasError) return s.settingsSyncStatusFailed;
    if (!isOnline) return s.syncStatusOffline;
    return s.syncStatusConnected;
  }

  String _heroSubtitle(AppLocalizations s) {
    if (isSyncing) return s.syncAutoSyncDescription;
    if (syncState.hasError) {
      return syncState.message ?? s.syncDefaultError;
    }
    return s.syncNoPendingItems;
  }

  String _formatLastSynced(DateTime dt, AppLocalizations s) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return s.settingsSyncStatusJustSynced;
    if (diff.inHours < 1) return s.settingsSyncStatusMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return s.settingsSyncStatusHoursAgo(diff.inHours);
    return s.settingsSyncStatusDaysAgo(diff.inDays);
  }
}

// ---------------------------------------------------------------------------
// Pending items card
// ---------------------------------------------------------------------------

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.pendingCount,
    required this.tokens,
    required this.s,
  });

  final AsyncValue<int> pendingCount;
  final DcoTokens tokens;
  final AppLocalizations s;

  @override
  Widget build(BuildContext context) {
    final count = pendingCount.valueOrNull ?? 0;
    final hasPending = count > 0;

    return _InfoCard(
      tokens: tokens,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasPending
                  ? tokens.status.warningFg.withValues(alpha: 0.12)
                  : tokens.status.successFg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(tokens.radius.md),
            ),
            child: Icon(
              hasPending
                  ? Icons.hourglass_top_rounded
                  : Icons.check_circle_outline,
              color: hasPending
                  ? tokens.status.warningFg
                  : tokens.status.successFg,
              size: 22,
            ),
          ),
          SizedBox(width: tokens.space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.syncPendingItems,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.space.s1),
                Text(
                  hasPending
                      ? '$count ${s.syncPendingItemsDescription}'
                      : s.syncNoPendingItems,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.text.secondary),
                ),
              ],
            ),
          ),
          if (hasPending)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.s2,
                vertical: tokens.space.s1,
              ),
              decoration: BoxDecoration(
                color: tokens.status.warningFg.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(tokens.radius.sm),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: tokens.status.warningFg,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How it works card
// ---------------------------------------------------------------------------

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.tokens, required this.s});

  final DcoTokens tokens;
  final AppLocalizations s;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: tokens.icon.inactive, size: 20),
              SizedBox(width: tokens.space.s2),
              Text(
                s.syncHowItWorks,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          SizedBox(height: tokens.space.s2),
          Text(
            s.syncHowItWorksDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.text.secondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: tokens.space.s3),
          _FeatureRow(
            icon: Icons.edit_note,
            label: s.syncVehicles,
            tokens: tokens,
          ),
          _FeatureRow(
            icon: Icons.build_outlined,
            label: s.syncMaintenance,
            tokens: tokens,
          ),
          _FeatureRow(
            icon: Icons.payments_outlined,
            label: s.syncExpenses,
            tokens: tokens,
          ),
          _FeatureRow(
            icon: Icons.description_outlined,
            label: s.syncDocuments,
            tokens: tokens,
          ),
          _FeatureRow(
            icon: Icons.settings_input_component_outlined,
            label: s.syncParts,
            tokens: tokens,
          ),
          _FeatureRow(
            icon: Icons.local_gas_station_outlined,
            label: s.syncFuelLogs,
            tokens: tokens,
          ),
          _FeatureRow(
            icon: Icons.more_horiz,
            label: s.syncOther,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.tokens, required this.child});

  final DcoTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        boxShadow: tokens.shadows.card,
      ),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: Padding(padding: EdgeInsets.all(tokens.space.s4), child: child),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.tokens,
  });

  final IconData icon;
  final String label;
  final Color color;
  final DcoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: tokens.space.s1),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.tokens,
  });

  final IconData icon;
  final String label;
  final DcoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tokens.icon.inactive),
          SizedBox(width: tokens.space.s2),
          Text(
            label,
            style: TextStyle(color: tokens.text.secondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

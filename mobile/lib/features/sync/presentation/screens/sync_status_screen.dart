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

    return Scaffold(
      appBar: AppBar(title: Text(s.syncStatusTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              boxShadow: tokens.shadows.card,
            ),
            child: Material(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              child: Padding(
                padding: EdgeInsets.all(tokens.space.s4),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            tokens.text.accent.withValues(alpha: 0.2),
                            tokens.text.accent.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(tokens.radius.md),
                      ),
                      child: Icon(
                        Icons.sync,
                        color: isSyncing
                            ? tokens.text.accent
                            : tokens.icon.inactive,
                      ),
                    ),
                    SizedBox(width: tokens.space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.settingsSyncNow,
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: tokens.space.s1),
                          Text(
                            _getStatusText(syncState, s),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: syncState.hasError
                                      ? tokens.status.dangerFg
                                      : tokens.text.secondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isSyncing)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.text.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.space.s4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSyncing
                  ? null
                  : () async {
                      await ref.read(syncEngineProvider).syncNow();
                    },
              child: Text(s.settingsSyncNow),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(SyncState state, AppLocalizations s) {
    if (state.hasError) {
      return state.message ?? s.settingsSyncStatusFailed;
    }
    if (state.phase == SyncPhase.syncing) {
      return s.settingsSyncStatusSyncing;
    }
    if (state.lastSyncedAt != null) {
      final diff = DateTime.now().difference(state.lastSyncedAt!);
      if (diff.inMinutes < 1) return s.settingsSyncStatusJustSynced;
      if (diff.inHours < 1) {
        return s.settingsSyncStatusMinutesAgo(diff.inMinutes);
      }
      if (diff.inDays < 1) {
        return s.settingsSyncStatusHoursAgo(diff.inHours);
      }
      return s.settingsSyncStatusDaysAgo(diff.inDays);
    }
    return s.settingsSyncTapToSync;
  }
}

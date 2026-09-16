import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final mockAuth = ref.watch(appConfigProvider).mockAuth;
    final prefs =
        ref.watch(userPreferencesProvider).valueOrNull ??
        UserPreferences.defaults;
    final syncState =
        ref.watch(syncStatusProvider).valueOrNull ?? const SyncState();

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                Material(
                  color: tokens.background.card,
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                  child: InkWell(
                    onTap: user?.id != null
                        ? () => context.push(AppRoutes.userDetail(user!.id))
                        : null,
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space.s4),
                      child: Row(
                        children: [
                          DcoAvatar(name: user?.email ?? '?', radius: 28),
                          SizedBox(width: tokens.space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.email ?? '',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                SizedBox(height: tokens.space.s1),
                                Text(
                                  s.settingsFreePlan,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: tokens.text.caption),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: tokens.icon.inactive,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.s4),
                if (!mockAuth) ...[
                  Text(
                    s.settingsSyncSection,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.text.primary,
                    ),
                  ),
                  SizedBox(height: tokens.space.s2),
                  _SyncButton(syncState: syncState),
                  SizedBox(height: tokens.space.s4),
                ],
                Text(
                  s.settingsFamilySection,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: tokens.text.primary),
                ),
                SizedBox(height: tokens.space.s2),
                ref
                    .watch(myFamilyProvider)
                    .when(
                      loading: () => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.settingsLoadingFamily),
                        leading: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, _) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.settingsFamilyLoadError),
                        subtitle: Text(s.settingsFamilyTapRetry),
                        onTap: () => ref.invalidate(myFamilyProvider),
                      ),
                      data: (family) {
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: family != null
                                  ? CircleAvatar(
                                      backgroundColor: tokens.text.accent,
                                      child: Text(
                                        family.name.isNotEmpty
                                            ? family.name[0].toUpperCase()
                                            : 'F',
                                        style: TextStyle(
                                          color: tokens.text.onAccent,
                                        ),
                                      ),
                                    )
                                  : null,
                              title: Text(
                                family?.name ?? s.settingsFamilyFallback,
                              ),
                              subtitle: family != null
                                  ? Text(
                                      '${family.myRole?.toUpperCase()} • Share Code: ${family.shareCode}',
                                    )
                                  : Text(s.settingsFamilySubtitle),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: tokens.icon.inactive,
                              ),
                              onTap: () => context.push(AppRoutes.familyManage),
                            ),
                          ],
                        );
                      },
                    ),
                SizedBox(height: tokens.space.s4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.settingsManageVehicles),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.garage),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.settingsDocuments),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.dashboardDocuments),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.settingsLocalization),
                  subtitle: Text(
                    prefs.language.label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.settingsLocalization),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.settingsUnitFormat),
                  subtitle: Text(
                    '${prefs.currency.code}, ${prefs.lengthUnit.fullLabel.toLowerCase()}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.settingsUnits),
                ),
                SizedBox(height: tokens.space.s2),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(tokens.space.s5),
            child: DcoButton(
              label: s.settingsSignOut,
              variant: DcoButtonVariant.destructive,
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).signOut(),
            ),
          ),
          SizedBox(height: 70),
        ],
      ),
    );
  }
}

class _SyncButton extends ConsumerWidget {
  const _SyncButton({required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final isSyncing = syncState.phase == SyncPhase.syncing;

    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: isSyncing
            ? null
            : () async {
                await ref.read(syncEngineProvider).syncNow();
              },
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s4),
          child: Row(
            children: [
              Icon(
                Icons.sync,
                color: isSyncing ? tokens.text.accent : tokens.icon.inactive,
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.settingsSyncNow,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.space.s1),
                    Text(
                      _getStatusText(syncState, s),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right, color: tokens.icon.inactive),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(SyncState state, AppLocalizations s) {
    if (state.hasError) return state.message ?? s.settingsSyncStatusFailed;
    if (state.phase == SyncPhase.syncing) return s.settingsSyncStatusSyncing;
    if (state.lastSyncedAt != null) {
      final diff = DateTime.now().difference(state.lastSyncedAt!);
      if (diff.inMinutes < 1) return s.settingsSyncStatusJustSynced;
      if (diff.inHours < 1)
        return s.settingsSyncStatusMinutesAgo(diff.inMinutes);
      if (diff.inDays < 1) return s.settingsSyncStatusHoursAgo(diff.inHours);
      return s.settingsSyncStatusDaysAgo(diff.inDays);
    }
    return s.settingsSyncTapToSync;
  }
}

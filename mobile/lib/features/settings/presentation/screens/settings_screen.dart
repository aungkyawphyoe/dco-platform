import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showLeaveFamilyDialog(BuildContext context, WidgetRef ref, family) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Family?'),
        content: Text(
          'Are you sure you want to leave "${family.name}"? You will lose access to all shared vehicles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave',
              style: TextStyle(color: context.tokens.status.dangerFg),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        final repo = ref.read(familyRepositoryProvider);
        // await repo.leaveFamily(); // Implement when leaveFamily is added to repository
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Left family')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final mockAuth = ref.watch(appConfigProvider).mockAuth;
    final prefs =
        ref.watch(userPreferencesProvider).valueOrNull ??
        UserPreferences.defaults;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                SizedBox(height: tokens.space.s1),
                                Text(
                                  'Free Plan',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tokens.text.caption,
                                  ),
                                ),
                                SizedBox(height: tokens.space.s1),
                                Text(
                                  mockAuth
                                      ? 'Local mock session'
                                      : 'Sync status: idle',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tokens.text.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: tokens.icon.inactive),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.s4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Manage vehicles'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.garage),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Documents'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.dashboardDocuments),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Localization'),
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
                  title: const Text('Unit and Format'),
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
                SizedBox(height: tokens.space.s4),
                Text(
                  'Family',
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
                        title: const Text('Loading family...'),
                        leading: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, _) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Failed to load family'),
                        subtitle: const Text('Tap to retry'),
                        onTap: () => ref.invalidate(myFamilyProvider),
                      ),
                      data: (family) {
                        if (family == null) {
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Create Family'),
                                subtitle: const Text(
                                  'Start a new family group to share vehicles',
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: tokens.icon.inactive,
                                ),
                                onTap: () =>
                                    context.push(AppRoutes.familyCreate),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Join Family'),
                                subtitle: const Text(
                                  'Enter a share code or scan QR to join a family',
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: tokens.icon.inactive,
                                ),
                                onTap: () =>
                                    context.push(AppRoutes.familyManage),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: tokens.text.accent,
                                child: Text(
                                  family.name.isNotEmpty
                                      ? family.name[0].toUpperCase()
                                      : 'F',
                                  style: TextStyle(color: tokens.text.onAccent),
                                ),
                              ),
                              title: Text(family.name),
                              subtitle: Text(
                                '${family.myRole?.toUpperCase()} • Share Code: ${family.shareCode}',
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: tokens.icon.inactive,
                              ),
                              onTap: () => context.push(AppRoutes.familyManage),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Leave Family'),
                              subtitle: const Text('Leave this family group'),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: tokens.icon.inactive,
                              ),
                              onTap: () =>
                                  _showLeaveFamilyDialog(context, ref, family),
                            ),
                          ],
                        );
                      },
                    ),
                SizedBox(height: tokens.space.s7),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(tokens.space.s5),
            child: DcoButton(
              label: 'Sign out',
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

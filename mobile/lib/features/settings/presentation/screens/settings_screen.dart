import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
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
    final prefs =
        ref.watch(userPreferencesProvider).valueOrNull ??
        UserPreferences.defaults;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu, color: tokens.icon.active),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text(s.settingsTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
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
                    child: InkWell(
                      onTap: () => context.push(AppRoutes.settingsProfile),
                      borderRadius: BorderRadius.circular(tokens.radius.lg),
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
                                    user?.displayName ?? user?.email ?? '',
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
                ),
                SizedBox(height: tokens.space.s3),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                    boxShadow: tokens.shadows.card,
                  ),
                  child: Material(
                    color: tokens.background.card,
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                    child: Column(
                      children: [
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tokens.radius.lg,
                            ),
                          ),
                          title: Text(s.settingsLocalization),
                          subtitle: Text(
                            prefs.language.label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.text.caption),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: tokens.icon.inactive,
                          ),
                          onTap: () =>
                              context.push(AppRoutes.settingsLocalization),
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          color: tokens.border.divider,
                        ),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tokens.radius.lg,
                            ),
                          ),
                          title: Text(s.settingsUnitFormat),
                          subtitle: Text(
                            '${prefs.currency.code}, ${prefs.lengthUnit.fullLabel.toLowerCase()}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.text.caption),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: tokens.icon.inactive,
                          ),
                          onTap: () => context.push(AppRoutes.settingsUnits),
                        ),
                      ],
                    ),
                  ),
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

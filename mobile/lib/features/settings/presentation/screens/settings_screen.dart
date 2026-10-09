import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
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
          ListTile(leading: const Icon(Icons.link), title: Text(s.authConnections), onTap: () => context.push(AppRoutes.accountConnections)),
          if (user != null && !user.emailVerified && user.email.isNotEmpty)
            ListTile(leading: const Icon(Icons.mark_email_unread_outlined), title: Text(s.authVerifyTitle), onTap: () => context.push(AppRoutes.verifyEmail)),
          InkWell(
            onTap: () {
              final id = user?.id;
              if (id != null) context.push(AppRoutes.profileDetail(id));
            },
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.space.s5,
                tokens.space.s5,
                tokens.space.s5,
                tokens.space.s1,
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DcoAvatar(
                        name: user?.displayName ?? user?.email ?? '?',
                        radius: 28,
                      ),
                      if (user?.plan != null && user?.plan != 'free')
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: tokens.background.card,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: tokens.button.primary.background,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.star,
                                size: 12,
                                color: tokens.text.disabled,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: tokens.space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          user?.displayName ?? user?.email ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                    child: Column(
                      children: [
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tokens.radius.lg,
                            ),
                          ),
                          leading: Icon(
                            Icons.language,
                            color: tokens.icon.inactive,
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
                          leading: Icon(
                            Icons.grid_3x3,
                            color: tokens.icon.inactive,
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
                          leading: Icon(
                            Icons.notifications_active_outlined,
                            color: tokens.icon.inactive,
                          ),
                          title: Text(s.settingsReminders),
                          subtitle: Text(
                            s.settingsRemindersSummary(
                              prefs.soonDays,
                              MileageFormat.labeled(
                                MileageUnit.km.toStorage(prefs.soonDistanceKm),
                                prefs.lengthUnit,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.text.caption),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: tokens.icon.inactive,
                          ),
                          onTap: () =>
                              context.push(AppRoutes.settingsReminders),
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
                          leading: Icon(
                            Icons.palette,
                            color: tokens.icon.inactive,
                          ),
                          title: Text(s.settingsAppearance),
                          subtitle: Text(
                            prefs.themeMode.label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.text.caption),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: tokens.icon.inactive,
                          ),
                          onTap: () =>
                              context.push(AppRoutes.settingsAppearance),
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

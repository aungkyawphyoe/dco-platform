import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/presentation/widgets/sign_out_button.dart';
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu, color: tokens.icon.active),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text(s.navMore),
      ),
      body: Column(
        children: [
          if (user != null && !user.emailVerified && user.email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: Text(s.authVerifyTitle),
              onTap: () => context.push(AppRoutes.verifyEmail),
            ),
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
                if (ref.watch(driverOrganizationIdProvider) == null)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(tokens.radius.lg),
                      boxShadow: tokens.shadows.card,
                    ),
                    child: Material(
                      color: tokens.background.card,
                      borderRadius: BorderRadius.circular(tokens.radius.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                tokens.radius.lg,
                              ),
                              onTap: () => context.push(AppRoutes.pricing),
                              child: Padding(
                                padding: EdgeInsets.all(tokens.space.s3),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium_outlined,
                                      color: tokens.icon.inactive,
                                    ),
                                    SizedBox(height: tokens.space.s1),
                                    Text(
                                      s.pricingTitle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: tokens.border.defaultColor,
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                tokens.radius.lg,
                              ),
                              onTap: () => context.push(AppRoutes.redeemGift),
                              child: Padding(
                                padding: EdgeInsets.all(tokens.space.s3),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.redeem,
                                      color: tokens.icon.inactive,
                                    ),
                                    SizedBox(height: tokens.space.s1),
                                    Text(
                                      s.pricingGiftCta,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (ref.watch(driverOrganizationIdProvider) == null)
                  SizedBox(height: tokens.space.s2),

                _section(context, s.moreManagement, [
                  if (ref.watch(driverOrganizationIdProvider) == null)
                    _row(
                      context,
                      Icons.people_outline,
                      s.sharedUsersTitle,
                      AppRoutes.sharedUsers,
                    ),
                  Divider(height: 1, indent: 16, color: tokens.border.divider),
                  _row(
                    context,
                    Icons.local_gas_station_outlined,
                    s.fuelTypesTitle,
                    AppRoutes.fuelTypes,
                  ),
                  Divider(height: 1, indent: 16, color: tokens.border.divider),
                  _row(
                    context,
                    Icons.build_outlined,
                    s.partsTitle,
                    AppRoutes.parts,
                  ),
                ]),
                _section(context, s.morePreferences, [
                  _row(
                    context,
                    Icons.settings_outlined,
                    s.settingsTitle,
                    AppRoutes.settingsPreferences,
                  ),
                ]),
                _section(context, s.moreSupport, [
                  _row(
                    context,
                    Icons.help_outline,
                    s.settingsHelp,
                    AppRoutes.settingsHelp,
                  ),
                  Divider(height: 1, indent: 16, color: tokens.border.divider),
                  _row(
                    context,
                    Icons.info_outline,
                    s.aboutTitle,
                    AppRoutes.about,
                  ),
                ]),
                SizedBox(height: tokens.space.s4),
                const SignOutButton(),
                SizedBox(height: tokens.space.s7),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> rows) =>
      Padding(
        padding: EdgeInsets.only(top: context.tokens.space.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: context.tokens.space.s2),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            DcoCard(
              padding: EdgeInsets.zero,
              child: Column(children: rows),
            ),
          ],
        ),
      );

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) => ListTile(
    leading: Icon(icon, color: context.tokens.icon.inactive),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}

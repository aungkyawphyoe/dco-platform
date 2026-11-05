import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final prefs =
        ref.watch(userPreferencesProvider).valueOrNull ??
        UserPreferences.defaults;
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          DcoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                  ),
                  leading: Icon(Icons.palette, color: tokens.icon.inactive),
                  title: Text(s.settingsAppearance),
                  subtitle: Text(
                    prefs.themeMode.label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.settingsAppearance),
                ),
                Divider(height: 1, indent: 16, color: tokens.border.divider),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                  ),
                  leading: Icon(Icons.language, color: tokens.icon.inactive),
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
                Divider(height: 1, indent: 16, color: tokens.border.divider),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                  ),
                  leading: Icon(Icons.grid_3x3, color: tokens.icon.inactive),
                  title: Text(s.settingsUnitFormat),
                  subtitle: Text(
                    '${ref.watch(currencyProvider).code}, ${prefs.lengthUnit.fullLabel.toLowerCase()}',
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
                Divider(height: 1, indent: 16, color: tokens.border.divider),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: tokens.icon.inactive,
                  ),
                  onTap: () => context.push(AppRoutes.settingsReminders),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

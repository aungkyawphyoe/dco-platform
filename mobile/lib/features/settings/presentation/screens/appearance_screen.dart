import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/presentation/widgets/settings_choice_row.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final prefs =
        ref.watch(userPreferencesProvider).valueOrNull ?? UserPreferences.defaults;
    final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;

    final s = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(s.appearanceTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Text(
            s.appearanceTheme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.space.s3),
          SettingsChoiceRow(
            options: AppThemeMode.values
                .map((mode) => (value: mode, label: mode.label))
                .toList(),
            selected: prefs.themeMode,
            onSelected: (mode) {
              if (userId == null) return;
              ref.read(preferencesRepositoryProvider).save(
                userId: userId,
                preferences: prefs.copyWith(themeMode: mode),
              );
            },
          ),
          SizedBox(height: tokens.space.s3),
          Text(
            s.appearanceSystemHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.text.caption,
            ),
          ),
        ],
      ),
    );
  }
}

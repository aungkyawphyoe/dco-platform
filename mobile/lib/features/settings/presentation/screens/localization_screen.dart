import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/presentation/widgets/settings_choice_row.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalizationScreen extends ConsumerWidget {
  const LocalizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull ?? UserPreferences.defaults;
    final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Localization')),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Text('Language', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.space.s2),
          Text(
            'App copy stays in English for now. This stores your choice.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s3),
          SettingsChoiceRow(
            options: AppLanguage.values
                .map((language) => (value: language, label: language.label))
                .toList(),
            selected: prefs.language,
            onSelected: (language) {
              if (userId == null) return;
              ref.read(preferencesRepositoryProvider).save(
                userId: userId,
                preferences: prefs.copyWith(language: language),
              );
            },
          ),
        ],
      ),
    );
  }
}

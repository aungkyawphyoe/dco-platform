import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final mockAuth = ref.watch(appConfigProvider).mockAuth;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull ?? UserPreferences.defaults;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Text(user?.email ?? '', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: tokens.space.s2),
          Text(
            'Free Plan',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s2),
          Text(
            mockAuth ? 'Local mock session · not talking to the API' : 'Sync status: idle',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
          ),
          SizedBox(height: tokens.space.s4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Manage vehicles'),
            trailing: Icon(Icons.chevron_right, color: tokens.icon.inactive),
            onTap: () => context.push(AppRoutes.garage),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Localization'),
            subtitle: Text(
              prefs.language.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
            ),
            trailing: Icon(Icons.chevron_right, color: tokens.icon.inactive),
            onTap: () => context.push(AppRoutes.settingsLocalization),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unit and Format'),
            subtitle: Text(
              '${prefs.currency.code}, ${prefs.lengthUnit.fullLabel.toLowerCase()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
            ),
            trailing: Icon(Icons.chevron_right, color: tokens.icon.inactive),
            onTap: () => context.push(AppRoutes.settingsUnits),
          ),
          SizedBox(height: tokens.space.s7),
          DcoButton(
            label: 'Sign out',
            variant: DcoButtonVariant.destructive,
            onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnitsFormatsScreen extends ConsumerWidget {
  const UnitsFormatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final prefs =
        ref.watch(userPreferencesProvider).valueOrNull ??
        UserPreferences.defaults;
    final currencyState = ref.watch(selectedCurrencyStateProvider);
    final isDriver = ref.watch(driverOrganizationIdProvider) != null;
    final currencyLabel = currencyState.when(
      loading: () => 'Loading currency…',
      error: (_, _) => 'Unable to load currency',
      data: (state) => state == null
          ? 'Sync to load your selected currency'
          : switch (state['currency']) {
              'MMK' => 'Myanmar Kyat (MMK)',
              'USD' => 'US Dollar (USD)',
              'THB' => 'Thai Baht (THB)',
              'CNY' => 'Chinese Yuan (CNY)',
              null => 'Not selected',
              _ => 'Unsupported currency',
            },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Unit and Format')),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Text('Currency', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.space.s2),
          Text(
            isDriver
                ? 'Your fleet uses the currency selected by its Fleet Admin. Amounts are not automatically converted.'
                : 'Your account uses the currency selected during setup. Amounts are not automatically converted.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s3),
          _DisplayTile(
            label: 'Currency',
            value: currencyLabel,
            icon: Icons.attach_money,
          ),
          SizedBox(height: tokens.space.s6),
          Text(
            'Unit of length',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.space.s2),
          Text(
            'Odometer, service intervals, and due mileage follow this unit.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s3),
          _DisplayTile(
            label: 'Unit of length',
            value: prefs.lengthUnit.fullLabel,
            icon: Icons.straighten,
          ),
        ],
      ),
    );
  }
}

class _DisplayTile extends StatelessWidget {
  const _DisplayTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        boxShadow: tokens.shadows.card,
      ),
      child: ListTile(
        leading: Icon(icon, color: tokens.icon.active),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.text.primary,
          ),
        ),
        subtitle: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
        ),
      ),
    );
  }
}

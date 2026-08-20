import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/presentation/widgets/settings_choice_row.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnitsFormatsScreen extends ConsumerWidget {
  const UnitsFormatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull ?? UserPreferences.defaults;
    final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;

    Future<void> save(UserPreferences next) async {
      if (userId == null) return;
      await ref.read(preferencesRepositoryProvider).save(userId: userId, preferences: next);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Unit and Format')),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Text('Currency', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.space.s2),
          Text(
            'Used when you log expenses. Amounts stay as you enter them.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s3),
          DropdownButtonFormField<AppCurrency>(
            key: ValueKey(prefs.currency),
            initialValue: prefs.currency,
            items: AppCurrency.values
                .map(
                  (currency) => DropdownMenuItem(
                    value: currency,
                    child: Text(currency.label),
                  ),
                )
                .toList(),
            onChanged: (currency) {
              if (currency == null) return;
              save(prefs.copyWith(currency: currency));
            },
          ),
          SizedBox(height: tokens.space.s6),
          Text('Unit of length', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.space.s2),
          Text(
            'Odometer, service intervals, and due mileage follow this unit.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s3),
          SettingsChoiceRow(
            options: MileageUnit.values
                .map((unit) => (value: unit, label: unit.fullLabel))
                .toList(),
            selected: prefs.lengthUnit,
            onSelected: (unit) => save(prefs.copyWith(lengthUnit: unit)),
          ),
        ],
      ),
    );
  }
}

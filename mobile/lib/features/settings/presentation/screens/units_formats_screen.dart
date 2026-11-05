import 'package:dco_mobile/core/currency/currency_store.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:intl/intl.dart';
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
    final account = currencyState.valueOrNull;
    final policy = ref.watch(vehicleCurrencyStateProvider).valueOrNull;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final user = ref.watch(currentUserIdProvider);
    final store = CurrencyStore(ref.watch(recordDatabaseProvider));
    final dio = ref.watch(dioProvider);
    final sync = ref.watch(syncEngineProvider);
    final choices = operationalCurrencies
        .map(
          (code) => DropdownMenuItem(
            value: code,
            child: Text(
              '$code · ${NumberFormat.simpleCurrency(name: code).format(100)}',
            ),
          ),
        )
        .toList();
    Future<void> savePolicy(String? base, bool overrides) async {
      if (vehicle == null || user == null) return;
      try {
        final url = '/vehicles/${vehicle.id}/currency';
        await dio.put(
          url,
          data: {'base_currency': base, 'allow_member_currency': overrides},
        );
        final result = await dio.get<Map<String, dynamic>>(url);
        await store.save(user, result.data!, vehicleId: vehicle.id);
      } catch (_) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save vehicle currency.')),
          );
      }
    }

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
                : 'Choose how vehicle costs are displayed. Amounts are not automatically converted.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s3),
          if (isDriver && policy?['allow_member_currency'] == true)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'My fleet display currency',
              ),
              value: policy?['currency'] as String?,
              items: choices,
              onChanged: (code) async {
                if (user == null || vehicle == null || code == null) return;
                final url =
                    '/organizations/${policy?['organization_id']}/vehicles/${vehicle.id}/currency';
                try {
                  await dio.put('$url/member', data: {'currency': code});
                  final response = await dio.get<Map<String, dynamic>>(url);
                  await store.save(user, response.data!, vehicleId: vehicle.id);
                  sync.requestSync();
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not save fleet display currency.'),
                      ),
                    );
                }
              },
            )
          else if (isDriver)
            Text(
              'Fleet currency · ${policy?['currency'] ?? account?['currency'] ?? '—'}',
            )
          else
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Account currency'),
              value: account?['currency'] as String?,
              items: choices,
              onChanged: (code) async {
                if (code == null || user == null) return;
                final history = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Change account currency?'),
                    content: const Text(
                      'You can also relabel every past fuel, service and expense log in your own vehicles. Numerical amounts stay the same.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Preference only'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Also relabel history'),
                      ),
                    ],
                  ),
                );
                if (history == null) return;
                try {
                  final current =
                      account ??
                      (await dio.get<Map<String, dynamic>>(
                        '/me/currency',
                      )).data!;
                  final response = await dio.put<Map<String, dynamic>>(
                    '/me/currency',
                    data: {
                      'currency': code,
                      'expected_currency': current['currency'],
                      'relabel_history': history,
                    },
                  );
                  await store.save(user, response.data!);
                  if (vehicle != null) {
                    final fresh = await dio.get<Map<String, dynamic>>(
                      '/vehicles/${vehicle.id}/currency',
                    );
                    await store.save(user, fresh.data!, vehicleId: vehicle.id);
                  }
                  sync.requestSync();
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not save currency. Sync and try again.',
                        ),
                      ),
                    );
                }
              },
            ),
          if (!isDriver && policy?['can_manage'] == true) ...[
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Base currency for ${vehicle?.displayName}',
              ),
              value: policy?['base_currency'] as String? ?? '',
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Use owner account currency'),
                ),
                ...choices,
              ],
              onChanged: (code) => savePolicy(
                code == '' ? null : code,
                policy?['allow_member_currency'] == true,
              ),
            ),
            SwitchListTile(
              title: const Text('Use each member’s account currency'),
              value: policy?['allow_member_currency'] == true,
              onChanged: (value) =>
                  savePolicy(policy?['base_currency'] as String?, value),
            ),
          ],
          SizedBox(height: tokens.space.s6),
          Text(
            'Unit of length',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.space.s2),
          Text(
            'Odometer, service intervals, and due odometer readings follow this unit.',
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

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
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
            'MMK shows whole kyat, and large amounts use K or M (25K, 23M).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s3),
          _DisplayTile(
            label: 'Currency',
            value: prefs.currency.label,
            icon: Icons.attach_money,
          ),
          SizedBox(height: tokens.space.s6),
          Text('Unit of length', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.space.s2),
          Text(
            'Odometer, service intervals, and due mileage follow this unit.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.text.secondary,
          ),
        ),
      ),
    );
  }
}

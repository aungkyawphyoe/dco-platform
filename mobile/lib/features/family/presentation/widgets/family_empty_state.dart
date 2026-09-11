import 'package:flutter/material.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';

class FamilyEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const FamilyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: tokens.text.tertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: tokens.text.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.tertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

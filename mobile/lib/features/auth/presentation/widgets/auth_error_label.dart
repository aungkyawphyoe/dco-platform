import 'package:flutter/material.dart';

import '../../../../core/theme/dco_tokens.dart';

/// Inline, form-level error label used across the auth flow. It keeps errors
/// next to the inputs instead of interrupting the user with a dialog.
class AuthErrorLabel extends StatelessWidget {
  const AuthErrorLabel({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final tokens = context.tokens;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('auth-inline-error'),
        width: double.infinity,
        padding: EdgeInsets.all(tokens.space.s3),
        decoration: BoxDecoration(
          color: tokens.status.dangerBg,
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: tokens.status.dangerFg),
            SizedBox(width: tokens.space.s2),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.status.dangerFg,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

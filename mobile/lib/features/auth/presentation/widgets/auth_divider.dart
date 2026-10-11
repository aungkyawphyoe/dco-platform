import 'package:flutter/material.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';

/// Centered "or" hairline divider between form actions and social sign-in.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(child: Divider(height: 1, color: tokens.border.divider)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space.s3),
          child: Text(
            s.authOr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.text.secondary,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, color: tokens.border.divider)),
      ],
    );
  }
}

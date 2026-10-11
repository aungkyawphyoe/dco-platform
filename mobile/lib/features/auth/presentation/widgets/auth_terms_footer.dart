import 'package:flutter/material.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';

/// Fixed terms notice for unauthenticated account screens.
///
/// Link-styled wording without targets: no legal pages exist yet, so the
/// phrases are intentionally not tappable.
class AuthTermsFooter extends StatelessWidget {
  const AuthTermsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: tokens.text.tertiary,
      height: 1.5,
    );
    final link = base?.copyWith(color: tokens.text.link);
    return Padding(
      padding: EdgeInsets.only(top: tokens.space.s5),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${s.authTermsIntro} ', style: base),
            TextSpan(text: s.termsOfService, style: link),
            TextSpan(text: ' ${s.authAnd} ', style: base),
            TextSpan(text: s.privacyPolicy, style: link),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

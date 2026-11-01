import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';

/// Fixed terms notice for unauthenticated account screens.
class AuthTermsFooter extends StatelessWidget {
  const AuthTermsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    final base = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary, height: 1.5);
    final link = base?.copyWith(color: tokens.text.link);
    return Padding(
      padding: EdgeInsets.only(top: tokens.space.s5),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${s.authTermsIntro} ', style: base),
            _legalLink(s.termsOfService, 'https://www.autoxmm.com/terms', link),
            TextSpan(text: ' ${s.authAnd} ', style: base),
            _legalLink(
              s.privacyPolicy,
              'https://www.autoxmm.com/privacy',
              link,
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  WidgetSpan _legalLink(String label, String url, TextStyle? style) =>
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Link(
          uri: Uri.parse(url),
          target: LinkTarget.blank,
          builder: (context, followLink) => TextButton(
            onPressed: followLink,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: style,
              foregroundColor: context.tokens.text.link,
            ),
            child: Text(label),
          ),
        ),
      );
}

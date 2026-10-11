import 'package:flutter/material.dart';

import '../../../../core/theme/dco_tokens.dart';

/// "Prefix **link**" line under an auth heading; the link is tappable.
class AuthSubtitleLink extends StatelessWidget {
  const AuthSubtitleLink({
    super.key,
    required this.prefix,
    required this.linkText,
    required this.onLink,
  });

  final String prefix;
  final String linkText;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final base = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: tokens.text.secondary,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$prefix ', style: base),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onLink,
              child: Text(
                linkText,
                style: base?.copyWith(
                  color: tokens.text.link,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

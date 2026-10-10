import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/dco_tokens.dart';

/// Renders an onboarding illustration SVG.
///
/// Text lives in localization resources; the SVG only carries artwork, so it
/// is excluded from semantics. In dark mode the art sits on a soft card stage
/// so the light vehicle reads against the dark background.
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: dark ? EdgeInsets.all(tokens.space.s5) : null,
      decoration: dark
          ? BoxDecoration(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.xl),
            )
          : null,
      child: AspectRatio(
        aspectRatio: 724 / 520,
        child: ExcludeSemantics(
          child: SvgPicture.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

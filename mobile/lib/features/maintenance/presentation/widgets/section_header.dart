import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:flutter/material.dart';

class MaintenanceSectionHeader extends StatelessWidget {
  const MaintenanceSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.tone = MaintenanceSectionTone.neutral,
  });

  final String title;
  final String? trailing;
  final MaintenanceSectionTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (fg, bg) = switch (tone) {
      MaintenanceSectionTone.danger => (tokens.status.dangerFg, tokens.status.dangerBg),
      MaintenanceSectionTone.info => (tokens.status.infoFg, tokens.status.infoBg),
      MaintenanceSectionTone.neutral => (tokens.text.primary, tokens.background.secondary),
    };
    return ColoredBox(
      color: bg,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.space.s4, vertical: tokens.space.s3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
              ),
          ],
        ),
      ),
    );
  }
}

enum MaintenanceSectionTone { danger, info, neutral }

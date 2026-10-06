import 'package:flutter/material.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../domain/entities/vehicle_share.dart';
import '../../../../generated/app_localizations.dart';

/// Compact pill showing a share's access level.
class ShareAccessBadge extends StatelessWidget {
  const ShareAccessBadge({super.key, required this.accessLevel});

  final ShareAccessLevel accessLevel;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final (label, color) = switch (accessLevel) {
      ShareAccessLevel.view => (
        s.shareAccessViewBadge,
        tokens.status.infoFg,
      ),
      ShareAccessLevel.addEditOwn => (
        s.shareAccessAddEditBadge,
        tokens.status.successFg,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1,
      ),
      decoration: BoxDecoration(
        color: tokens.background.input,
        borderRadius: BorderRadius.circular(tokens.radius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Radio-style picker for the two access levels.
class ShareAccessLevelField extends StatelessWidget {
  const ShareAccessLevelField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ShareAccessLevel value;
  final ValueChanged<ShareAccessLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.shareAccessLabel,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: tokens.text.secondary),
        ),
        SizedBox(height: tokens.space.s2),
        for (final level in ShareAccessLevel.values)
          _Option(
            selected: value == level,
            onTap: () => onChanged(level),
            title: switch (level) {
              ShareAccessLevel.view => s.shareAccessView,
              ShareAccessLevel.addEditOwn => s.shareAccessAddEditOwn,
            },
            subtitle: switch (level) {
              ShareAccessLevel.view => s.shareAccessViewDescription,
              ShareAccessLevel.addEditOwn => s.shareAccessAddEditOwnDescription,
            },
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s2),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(tokens.space.s3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius.md),
              border: Border.all(
                color: selected
                    ? tokens.text.accent
                    : tokens.border.defaultColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: selected ? tokens.text.accent : tokens.icon.inactive,
                ),
                SizedBox(width: tokens.space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: tokens.text.primary),
                      ),
                      SizedBox(height: tokens.space.s1),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.text.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

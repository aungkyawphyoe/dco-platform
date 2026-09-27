import 'package:flutter/material.dart';

import '../../../../core/theme/dco_tokens.dart';

/// Small colored status pill — keeps status readable without relying on
/// color alone (text always present).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;

  /// success | warning | danger | info
  final String tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (fg, bg) = switch (tone) {
      'success' => (tokens.status.successFg, tokens.status.successBg),
      'warning' => (tokens.status.warningFg, tokens.status.warningBg),
      'danger' => (tokens.status.dangerFg, tokens.status.dangerBg),
      _ => (tokens.status.infoFg, tokens.status.infoBg),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1 / 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

String orgStatusTone(String status) => switch (status) {
  'active' => 'success',
  'pending' => 'warning',
  _ => 'danger',
};

/// Vehicle lifecycle statuses — calmer tones than org status.
String vehicleStatusTone(String status) => switch (status) {
  'available' || 'listed' || 'leased' || 'rented' || 'in_service' => 'success',
  'inventory' || 'inspection' || 'maintenance' || 'return' => 'warning',
  _ => 'info',
};

String workOrderTone(String status) => switch (status) {
  'completed' => 'success',
  'in_progress' => 'warning',
  _ => 'danger',
};

String urgencyTone(String urgency) => switch (urgency) {
  'low' => 'info',
  'medium' => 'warning',
  'high' => 'danger',
  _ => 'danger',
};

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        top: tokens.space.s4,
        bottom: tokens.space.s2,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.text.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Standard tappable row for hub / manage lists.
class FleetTile extends StatelessWidget {
  const FleetTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Card(
      margin: EdgeInsets.only(bottom: tokens.space.s2),
      child: ListTile(
        leading: Icon(icon, color: tokens.icon.inactive),
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.text.caption,
                ),
              ),
        trailing:
            trailing ??
            (onTap == null
                ? null
                : Icon(Icons.chevron_right, color: tokens.icon.inactive)),
        onTap: onTap,
      ),
    );
  }
}

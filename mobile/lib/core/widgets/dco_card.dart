import 'package:flutter/material.dart';
import '../theme/dco_tokens.dart';

/// App card surface: depth comes from the theme shadow, never an outline.
/// Keep focus indicators on interactive controls, not permanent card borders.
class DcoCard extends StatelessWidget {
  const DcoCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.emphasized = false,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radius.lg);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? t.background.card,
        borderRadius: radius,
        boxShadow: emphasized ? t.shadows.elevated : t.shadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: padding ?? EdgeInsets.all(t.space.s5),
            child: child,
          ),
        ),
      ),
    );
  }
}

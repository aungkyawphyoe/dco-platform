import 'package:flutter/material.dart';
import '../theme/dco_tokens.dart';

class DcoFilterChip extends StatelessWidget {
  const DcoFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? tokens.button.primary.background
            : tokens.background.input,
        borderRadius: BorderRadius.circular(tokens.radius.full),
        elevation: selected ? 2 : 0,
        shadowColor: selected
            ? tokens.text.accent.withValues(alpha: 0.3)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.full),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space.s4),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? tokens.text.onAccent
                        : tokens.text.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

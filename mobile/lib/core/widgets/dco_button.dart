import 'package:flutter/material.dart';

import '../theme/dco_tokens.dart';

enum DcoButtonVariant { primary, secondary, tertiary, destructive }

class DcoButton extends StatelessWidget {
  const DcoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DcoButtonVariant.primary,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DcoButtonVariant variant;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = switch (variant) {
      DcoButtonVariant.primary => tokens.button.primary,
      DcoButtonVariant.secondary => tokens.button.secondary,
      DcoButtonVariant.tertiary => tokens.button.tertiary,
      DcoButtonVariant.destructive => tokens.button.destructive,
    };
    final enabled = onPressed != null && !loading;
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: enabled ? colors.text : colors.textDisabled,
            ),
          )
        : Text(label);

    final button = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? colors.background : colors.backgroundDisabled,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          border: colors.border.a == 0
              ? null
              : Border.all(color: enabled ? colors.border : colors.textDisabled),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(tokens.radius.md),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.s5,
                vertical: tokens.space.s3,
              ),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: enabled ? colors.text : colors.textDisabled,
                ),
                textAlign: TextAlign.center,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:flutter/material.dart';

class DcoStickyActions extends StatelessWidget {
  const DcoStickyActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryLoading = false,
    this.primaryKey,
    this.secondaryKey,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryLoading;
  final Key? primaryKey;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.background.primary,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.space.s4,
          tokens.space.s3,
          tokens.space.s4,
          tokens.space.s4,
        ),
        child: Row(
          children: [
            if (secondaryLabel != null) ...[
              Expanded(
                child: DcoButton(
                  key: secondaryKey,
                  label: secondaryLabel!,
                  variant: DcoButtonVariant.secondary,
                  onPressed: onSecondary,
                ),
              ),
              SizedBox(width: tokens.space.s3),
            ],
            Expanded(
              child: DcoButton(
                key: primaryKey,
                label: primaryLabel,
                onPressed: onPrimary,
                loading: primaryLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

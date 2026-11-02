import 'package:flutter/material.dart';

import '../theme/dco_tokens.dart';

/// Filled alert surface for a persistent, recoverable error. It sits inline in
/// the page (unlike [DcoErrorDialog], which interrupts the user).
class DcoAlertBox extends StatelessWidget {
  const DcoAlertBox({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(tokens.space.s4),
        decoration: BoxDecoration(
          color: tokens.status.dangerBg,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tokens.status.dangerFg, size: 22),
            SizedBox(width: tokens.space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: tokens.status.dangerFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: tokens.space.s1),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.secondary,
                      height: 1.4,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    SizedBox(height: tokens.space.s2),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: tokens.status.dangerFg,
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.space.s2,
                        ),
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

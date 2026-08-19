import 'package:flutter/material.dart';

import '../theme/dco_tokens.dart';
import 'dco_button.dart';

class DcoEmptyState extends StatelessWidget {
  const DcoEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.all(tokens.space.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          SizedBox(height: tokens.space.s3),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: tokens.space.s5),
            DcoButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

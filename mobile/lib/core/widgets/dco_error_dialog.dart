import 'package:flutter/material.dart';

import '../theme/dco_tokens.dart';

/// Shows the app-wide error dialog on the root navigator.
Future<void> showDcoErrorDialog(
  BuildContext context, {
  String title = 'Something went wrong',
  required String message,
  String actionLabel = 'OK',
  VoidCallback? onAction,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => DcoErrorDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

class DcoErrorDialog extends StatelessWidget {
  const DcoErrorDialog({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.actionLabel = 'OK',
    this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      backgroundColor: tokens.background.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        side: BorderSide(color: tokens.border.defaultColor),
      ),
      icon: Icon(Icons.error_outline, color: tokens.status.dangerFg, size: 32),
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      content: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: tokens.text.secondary),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding:
          EdgeInsets.fromLTRB(tokens.space.s5, 0, tokens.space.s5, tokens.space.s4),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction?.call();
            },
            style: TextButton.styleFrom(foregroundColor: tokens.text.accent),
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

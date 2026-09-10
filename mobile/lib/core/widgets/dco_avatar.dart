import 'package:flutter/material.dart';

import '../theme/dco_tokens.dart';

class DcoAvatar extends StatelessWidget {
  const DcoAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final initials = _getInitials(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? tokens.text.accent,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: textColor ?? tokens.text.onAccent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

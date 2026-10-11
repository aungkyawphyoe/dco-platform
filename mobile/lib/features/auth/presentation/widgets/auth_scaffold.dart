import 'package:flutter/material.dart';

import '../../../../core/theme/dco_tokens.dart';
import 'language_action.dart';

/// Shared shell for unauthenticated account screens (login, signup, recovery):
/// title-less app bar (language switcher stays reachable pre-login — FRD),
/// large body heading, optional subtitle, and a staggered fade-up entrance.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.heading,
    this.subtitle,
    required this.children,
  });

  final String heading;
  final Widget? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(actions: const [LanguageAction()]),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.space.s5),
          children: [
            _AuthEntrance(
              delayFraction: 0,
              child: Text(
                heading,
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: tokens.space.s2),
              _AuthEntrance(delayFraction: 0.1, child: subtitle!),
            ],
            SizedBox(height: tokens.space.s5),
            for (var i = 0; i < children.length; i++)
              _AuthEntrance(
                delayFraction: 0.2 + 0.05 * i,
                child: children[i],
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthEntrance extends StatelessWidget {
  const _AuthEntrance({required this.delayFraction, required this.child});

  final double delayFraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final duration = Duration(milliseconds: tokens.motion.base);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(
        delayFraction.clamp(0.0, 0.8),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

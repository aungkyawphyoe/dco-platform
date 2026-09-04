import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const DcoLogo(),
              SizedBox(height: tokens.space.s3),
              Text('Your garage, on the phone.', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.space.s3),
              Text(
                'Track maintenance, documents, and spend for every vehicle you own — even offline.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
              ),
              const Spacer(),
              DcoButton(
                label: 'Create account',
                onPressed: () => context.push(AppRoutes.signup),
              ),
              SizedBox(height: tokens.space.s3),
              DcoButton(
                key: const Key('welcome-sign-in'),
                label: 'Sign in',
                variant: DcoButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthLoadingScreen extends ConsumerWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DcoLogo(size: 96),
            SizedBox(height: tokens.space.s5),
            CircularProgressIndicator(color: tokens.text.accent),
          ],
        ),
      ),
    );
  }
}

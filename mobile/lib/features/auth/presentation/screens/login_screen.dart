import '../widgets/auth_divider.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_subtitle_link.dart';
import '../widgets/auth_terms_footer.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_buttons.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_error_dialog.dart';
import 'package:dco_mobile/generated/app_localizations.dart';

import '../../domain/auth_failure.dart';
import '../../domain/auth_validators.dart';
import '../session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _identifierError;
  String? _passwordError;
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = AppLocalizations.of(context)!;
    setState(() {
      _identifierError = AuthValidators.identifier(_identifier.text) == null
          ? null
          : s.authInvalidIdentifier;
      _passwordError = AuthValidators.password(_password.text) == null
          ? null
          : s.authPasswordRequired;
      _formError = null;
    });
    if (_identifierError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(email: _identifier.text, password: _password.text);
    } catch (failure) {
      if (!mounted) return;
      final message = authFeedback(context, failure);
      if (mounted) {
        setState(() => _formError = message);
        unawaited(
          showDcoErrorDialog(
            context,
            title: s.signInFailed,
            message: message,
            actionLabel: failure is NetworkAuthFailure ? s.retry : s.ok,
            onAction: failure is NetworkAuthFailure ? () => _submit() : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return AuthScaffold(
      heading: s.signIn,
      subtitle: AuthSubtitleLink(
        prefix: s.authNewUser,
        linkText: s.createAnAccount,
        onLink: () => context.go(AppRoutes.signup),
      ),
      children: [
        AuthTextField(
          label: s.identifierLabel,
          controller: _identifier,
          hint: s.identifierHint,
          errorText: _identifierError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [
            AutofillHints.email,
            AutofillHints.username,
          ],
          icon: Icons.mail_outline,
          onChanged: (_) => setState(() => _identifierError = null),
        ),
        SizedBox(height: tokens.space.s4),
        AuthTextField(
          label: s.passwordLabel,
          controller: _password,
          obscureText: true,
          errorText: _passwordError,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          icon: Icons.lock_outline,
          onChanged: (_) => setState(() => _passwordError = null),
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: tokens.space.s2),
            ),
            onPressed: () => context.push(AppRoutes.forgotPassword),
            child: Text(
              s.forgotPassword,
              style: TextStyle(color: tokens.text.link),
            ),
          ),
        ),
        if (_formError != null) ...[
          Text(
            _formError!,
            style: TextStyle(color: tokens.status.dangerFg),
          ),
          SizedBox(height: tokens.space.s3),
        ],
        DcoButton(
          key: const Key('login-submit'),
          label: s.signIn,
          onPressed: _submit,
          loading: _submitting,
        ),
        SizedBox(height: tokens.space.s5),
        const AuthDivider(),
        SizedBox(height: tokens.space.s4),
        Text(
          s.authSocialHeading,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.text.secondary,
          ),
        ),
        SizedBox(height: tokens.space.s3),
        const SocialButtons(),
        const AuthTermsFooter(),
      ],
    );
  }
}

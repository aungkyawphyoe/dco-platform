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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = AppLocalizations.of(context)!;
    setState(() {
      _emailError = AuthValidators.email(_email.text) == null
          ? null
          : s.authInvalidEmail;
      _passwordError = AuthValidators.password(_password.text) == null
          ? null
          : s.authPasswordRequired;
      _confirmError =
          AuthValidators.confirmPassword(_confirm.text, _password.text) == null
          ? null
          : s.authPasswordMismatch;
      _formError = null;
    });
    if (_emailError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signUp(email: _email.text, password: _password.text);
    } catch (failure) {
      if (!mounted) return;
      final message = authFeedback(context, failure);
      if (mounted) {
        setState(() => _formError = message);
        unawaited(
          showDcoErrorDialog(
            context,
            title: s.signUpFailed,
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
      heading: s.createAccount,
      subtitle: AuthSubtitleLink(
        prefix: s.alreadyHaveAccountPrefix,
        linkText: s.signIn,
        onLink: () => context.go(AppRoutes.login),
      ),
      children: [
        AuthTextField(
          label: s.emailLabel,
          controller: _email,
          hint: s.emailHint,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          icon: Icons.mail_outline,
          onChanged: (_) => setState(() => _emailError = null),
        ),
        SizedBox(height: tokens.space.s4),
        AuthTextField(
          label: s.passwordLabel,
          controller: _password,
          obscureText: true,
          errorText: _passwordError,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          icon: Icons.lock_outline,
          onChanged: (_) => setState(() => _passwordError = null),
        ),
        SizedBox(height: tokens.space.s4),
        AuthTextField(
          label: s.confirmPasswordLabel,
          controller: _confirm,
          obscureText: true,
          errorText: _confirmError,
          textInputAction: TextInputAction.done,
          icon: Icons.lock_outline,
          onChanged: (_) => setState(() => _confirmError = null),
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: tokens.space.s3),
        if (_formError != null) ...[
          Text(
            _formError!,
            style: TextStyle(color: tokens.status.dangerFg),
          ),
          SizedBox(height: tokens.space.s3),
        ],
        DcoButton(
          key: const Key('signup-submit'),
          label: s.createAccount,
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

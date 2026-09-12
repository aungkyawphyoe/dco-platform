import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_error_dialog.dart';
import '../../../../core/widgets/dco_text_field.dart';
import 'package:dco_mobile/generated/app_localizations.dart';

import '../../domain/auth_failure.dart';
import '../../domain/auth_validators.dart';
import '../session_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _emailError;
  String? _info;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = AppLocalizations.of(context)!;
    setState(() {
      _emailError = AuthValidators.email(_email.text);
      _info = null;
    });
    if (_emailError != null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(sessionControllerProvider.notifier).requestPasswordReset(email: _email.text);
      if (mounted) {
        setState(() {
          _info = s.resetLinkSent;
        });
      }
    } catch (failure) {
      final message =
          failure is AuthFailure ? failure.message : s.somethingWentWrongTryAgain;
      if (mounted) {
        setState(() => _info = message);
        unawaited(
          showDcoErrorDialog(
            context,
            title: s.resetFailed,
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
    return Scaffold(
      appBar: AppBar(title: Text(s.resetPassword)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.space.s5),
          children: [
            Text(
              s.resetPasswordBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
            ),
            SizedBox(height: tokens.space.s5),
            DcoTextField(
              label: s.emailLabel,
              controller: _email,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: tokens.space.s5),
            if (_info != null) ...[
              Text(_info!, style: TextStyle(color: tokens.status.infoFg)),
              SizedBox(height: tokens.space.s3),
            ],
            DcoButton(label: s.sendResetLink, onPressed: _submit, loading: _submitting),
          ],
        ),
      ),
    );
  }
}

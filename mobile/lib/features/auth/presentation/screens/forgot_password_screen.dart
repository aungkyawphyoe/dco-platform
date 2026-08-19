import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_text_field.dart';
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
          _info = 'If that email is registered, we sent a reset link.';
        });
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _info = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.space.s5),
          children: [
            Text(
              'Enter your email. We send a reset link if the account exists.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
            ),
            SizedBox(height: tokens.space.s5),
            DcoTextField(
              label: 'Email',
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
            DcoButton(label: 'Send reset link', onPressed: _submit, loading: _submitting),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_text_field.dart';
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
    setState(() {
      _emailError = AuthValidators.email(_email.text);
      _passwordError = AuthValidators.password(_password.text);
      _confirmError = AuthValidators.confirmPassword(_confirm.text, _password.text);
      _formError = null;
    });
    if (_emailError != null || _passwordError != null || _confirmError != null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(sessionControllerProvider.notifier).signUp(
        email: _email.text,
        password: _password.text,
      );
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.space.s5),
          children: [
            DcoTextField(
              label: 'Email',
              controller: _email,
              hint: 'you@example.com',
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() => _emailError = null),
            ),
            SizedBox(height: tokens.space.s4),
            DcoTextField(
              label: 'Password',
              controller: _password,
              obscureText: true,
              errorText: _passwordError,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _passwordError = null),
            ),
            SizedBox(height: tokens.space.s4),
            DcoTextField(
              label: 'Confirm password',
              controller: _confirm,
              obscureText: true,
              errorText: _confirmError,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _confirmError = null),
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: tokens.space.s5),
            if (_formError != null) ...[
              Text(_formError!, style: TextStyle(color: tokens.status.dangerFg)),
              SizedBox(height: tokens.space.s3),
            ],
            DcoButton(label: 'Create account', onPressed: _submit, loading: _submitting),
            SizedBox(height: tokens.space.s4),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: Text('Already have an account? Sign in', style: TextStyle(color: tokens.text.link)),
            ),
          ],
        ),
      ),
    );
  }
}

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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = AuthValidators.email(_email.text);
      _passwordError = AuthValidators.password(_password.text);
      _formError = null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(sessionControllerProvider.notifier).signIn(
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
      appBar: AppBar(title: const Text('Sign in')),
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() => _passwordError = null),
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.forgotPassword),
                child: Text('Forgot password', style: TextStyle(color: tokens.text.link)),
              ),
            ),
            if (_formError != null) ...[
              Text(_formError!, style: TextStyle(color: tokens.status.dangerFg)),
              SizedBox(height: tokens.space.s3),
            ],
            DcoButton(
              key: const Key('login-submit'),
              label: 'Sign in',
              onPressed: _submit,
              loading: _submitting,
            ),
            SizedBox(height: tokens.space.s4),
            TextButton(
              onPressed: () => context.go(AppRoutes.signup),
              child: Text('Create an account', style: TextStyle(color: tokens.text.link)),
            ),
          ],
        ),
      ),
    );
  }
}

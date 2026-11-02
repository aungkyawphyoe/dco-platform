import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_text_field.dart';
import 'package:dco_mobile/generated/app_localizations.dart';

import '../../domain/auth_failure.dart';
import '../../domain/auth_validators.dart';
import '../session_controller.dart';
import '../widgets/auth_error_label.dart';
import '../widgets/auth_feedback.dart';

/// Forced password change screen shown when must_change_password=true.
/// Used for driver accounts and fleet admin temporary passwords.
class ForcedChangePasswordScreen extends ConsumerStatefulWidget {
  const ForcedChangePasswordScreen({super.key});

  @override
  ConsumerState<ForcedChangePasswordScreen> createState() =>
      _ForcedChangePasswordScreenState();
}

class _ForcedChangePasswordScreenState
    extends ConsumerState<ForcedChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _currentError = AuthValidators.password(_current.text);
      _newError = AuthValidators.password(_new.text);
      _confirmError = AuthValidators.confirmPassword(_confirm.text, _new.text);
      _formError = null;
    });
    if (_currentError != null || _newError != null || _confirmError != null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } catch (failure) {
      if (!mounted) return;
      final message = authFeedback(context, failure);
      setState(() {
        if (failure is ApiAuthFailure && failure.code == 'invalid_password') {
          _currentError = message;
        } else {
          _formError = message;
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.changePassword)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.space.s5),
          children: [
            Text(
              s.forcedPasswordChangeBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
            ),
            SizedBox(height: tokens.space.s5),
            DcoTextField(
              label: s.currentPasswordLabel,
              controller: _current,
              obscureText: true,
              errorText: _currentError,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() => _currentError = null),
            ),
            SizedBox(height: tokens.space.s4),
            DcoTextField(
              label: s.newPasswordLabel,
              controller: _new,
              obscureText: true,
              errorText: _newError,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _newError = null),
            ),
            SizedBox(height: tokens.space.s4),
            DcoTextField(
              label: s.confirmPasswordLabel,
              controller: _confirm,
              obscureText: true,
              errorText: _confirmError,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _confirmError = null),
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: tokens.space.s5),
            if (_formError != null) ...[
              AuthErrorLabel(message: _formError),
              SizedBox(height: tokens.space.s3),
            ],
            DcoButton(
              label: s.changePassword,
              onPressed: _submit,
              loading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

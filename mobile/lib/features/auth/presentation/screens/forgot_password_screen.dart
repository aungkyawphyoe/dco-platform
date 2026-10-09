import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../generated/app_localizations.dart';
import '../../account_security_providers.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/language_action.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String? challenge, error;
  bool busy = false, done = false;
  DateTime? resendAt;
  Timer? timer;
  int get remaining => resendAt == null
      ? 0
      : resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 60);
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && resendAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> run({bool send = false}) async {
    final s = AppLocalizations.of(context)!;
    if (!send && (password.text.length < 8 || password.text != confirm.text)) {
      setState(() => error = s.authPasswordMismatch);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(accountSecurityProvider);
      if (send) {
        final result = await api.request('/auth/recovery-code', {
          'email': email.text.trim(),
          'locale': Localizations.localeOf(context).languageCode,
        });
        if (mounted) {
          setState(() {
            challenge = result['challenge_id'] as String;
            resendAt = DateTime.now().add(
              Duration(seconds: result['resend_after'] as int),
            );
            code.clear();
          });
        }
      } else {
        await api.request('/auth/recovery-code/confirm', {
          'challenge_id': challenge,
          'code': code.text,
          'password': password.text,
        });
        if (mounted) setState(() => done = true);
      }
    } catch (e) {
      if (mounted) setState(() => error = authFeedback(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.resetPassword),
        actions: const [LanguageAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(done ? s.authResetDone : s.authRecoveryInfo),
            const SizedBox(height: 24),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (done)
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: Text(s.signIn),
              )
            else ...[
              TextField(
                controller: email,
                enabled: !busy,
                decoration: InputDecoration(labelText: s.emailLabel),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => setState(() => challenge = null),
              ),
              TextButton(
                onPressed: busy || remaining > 0 ? null : () => run(send: true),
                child: Text(
                  remaining > 0
                      ? '${s.authResend} (${remaining}s)'
                      : s.authSendCode,
                ),
              ),
              if (challenge != null) ...[
                TextField(
                  controller: code,
                  decoration: InputDecoration(labelText: s.authCode),
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                TextField(
                  controller: password,
                  decoration: InputDecoration(labelText: s.passwordLabel),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                TextField(
                  controller: confirm,
                  decoration: InputDecoration(
                    labelText: s.confirmPasswordLabel,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : run,
                  child: Text(s.resetPassword),
                ),
              ],
              if (busy) const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

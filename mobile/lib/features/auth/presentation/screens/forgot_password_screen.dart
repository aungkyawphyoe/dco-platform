import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../generated/app_localizations.dart';
import '../../account_security_providers.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

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
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return AuthScaffold(
      heading: s.resetPassword,
      subtitle: Text(
        done ? s.authResetDone : s.authRecoveryInfo,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
      ),
      children: [
        if (error != null) ...[
          Text(
            error!,
            style: TextStyle(color: tokens.status.dangerFg),
          ),
          SizedBox(height: tokens.space.s3),
        ],
        if (done)
          DcoButton(
            key: const Key('forgot-back-to-sign-in'),
            label: s.signIn,
            onPressed: () => context.go(AppRoutes.login),
          )
        else ...[
          AuthTextField(
            label: s.emailLabel,
            controller: email,
            enabled: !busy,
            hint: s.emailHint,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            icon: Icons.mail_outline,
            onChanged: (_) => setState(() => challenge = null),
          ),
          SizedBox(height: tokens.space.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('forgot-send-code'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: tokens.space.s2),
              ),
              onPressed: busy || remaining > 0 ? null : () => run(send: true),
              child: Text(
                remaining > 0
                    ? '${s.authResend} (${remaining}s)'
                    : s.authSendCode,
                style: TextStyle(color: tokens.text.link),
              ),
            ),
          ),
          if (challenge != null) ...[
            AuthTextField(
              label: s.authCode,
              controller: code,
              hint: s.authCode,
              maxLength: 6,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              icon: Icons.pin_outlined,
            ),
            SizedBox(height: tokens.space.s4),
            AuthTextField(
              label: s.passwordLabel,
              controller: password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              icon: Icons.lock_outline,
            ),
            SizedBox(height: tokens.space.s4),
            AuthTextField(
              label: s.confirmPasswordLabel,
              controller: confirm,
              obscureText: true,
              icon: Icons.lock_outline,
            ),
            SizedBox(height: tokens.space.s4),
            DcoButton(
              key: const Key('forgot-submit'),
              label: s.resetPassword,
              onPressed: busy ? null : run,
              loading: busy,
            ),
          ],
          if (busy) ...[
            SizedBox(height: tokens.space.s3),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ],
    );
  }
}

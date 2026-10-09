import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../generated/app_localizations.dart';
import '../../account_security_providers.dart';
import '../session_controller.dart';
import '../widgets/auth_feedback.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final code = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  String? challenge, error;
  bool busy = false, correcting = false;
  DateTime? resendAt;
  Timer? timer;
  int get remaining => resendAt == null
      ? 0
      : resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 60);
  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider).valueOrNull?.user;
    email.text = user?.email ?? '';
    correcting = email.text.isEmpty;
    Future.microtask(() {
      if (mounted && !correcting && user?.emailVerified == false) send();
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && resendAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(accountSecurityProvider);
      final result = await api
          .request(correcting ? '/auth/email-correction' : '/auth/email-code', {
            'locale': Localizations.localeOf(context).languageCode,
            if (correcting) 'email': email.text.trim(),
            if (password.text.isNotEmpty) 'password': password.text,
          });
      if (!mounted) return;
      setState(() {
        challenge = result['challenge_id'] as String;
        resendAt = DateTime.now().add(
          Duration(seconds: result['resend_after'] as int),
        );
        correcting = false;
        code.clear();
      });
      // Refresh the corrected address without rotating or replacing the account.
      final session = ref.read(sessionControllerProvider).valueOrNull;
      if (session != null) {
        ref
            .read(sessionControllerProvider.notifier)
            .updateUser(session.user.copyWith(email: email.text.trim()));
      }
    } catch (e) {
      if (mounted) setState(() => error = authFeedback(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirm() async {
    if (challenge == null || code.text.length != 6) {
      setState(() => error = AppLocalizations.of(context)!.authCodeInvalid);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(accountSecurityProvider).request(
        '/auth/email-code/confirm',
        {'challenge_id': challenge, 'code': code.text},
      );
      await ref.read(sessionControllerProvider.notifier).refreshAccount();
      if (mounted) finish(true);
    } catch (e) {
      if (mounted) setState(() => error = authFeedback(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void finish(bool verified) {
    ref.read(postAuthRouteProvider.notifier).state = null;
    final pending = ref.read(pendingCollaborationProvider);
    final setup = ref.read(newOwnerSetupProvider);
    if (verified && pending != null) {
      ref.read(pendingCollaborationProvider.notifier).state = null;
      context.go(pending);
    } else {
      context.go(setup ? AppRoutes.firstVehicle : AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.authVerifyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 72),
            const SizedBox(height: 24),
            Text(s.authVerifyBody),
            const SizedBox(height: 12),
            Text(email.text),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (correcting) ...[
              TextField(
                controller: email,
                decoration: InputDecoration(labelText: s.emailLabel),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              TextField(
                controller: password,
                decoration: InputDecoration(labelText: s.passwordLabel),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
              ),
              FilledButton(
                onPressed: busy ? null : send,
                child: Text(s.authSendCode),
              ),
            ] else ...[
              TextField(
                controller: code,
                decoration: InputDecoration(labelText: s.authCode),
                maxLength: 6,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => busy ? null : confirm(),
              ),
              FilledButton(
                onPressed: busy || challenge == null ? null : confirm,
                child: Text(s.authCheckCode),
              ),
              TextButton(
                onPressed: busy || remaining > 0 ? null : send,
                child: Text(
                  remaining > 0
                      ? '${s.authResend} (${remaining}s)'
                      : s.authResend,
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => correcting = true),
                child: Text(s.authCorrectEmail),
              ),
            ],
            if (busy) const LinearProgressIndicator(),
            TextButton(
              onPressed: busy ? null : () => finish(false),
              child: Text(s.authLater),
            ),
          ],
        ),
      ),
    );
  }
}

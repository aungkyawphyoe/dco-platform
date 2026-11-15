import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_card.dart';
import '../../domain/repositories/account_security_repository.dart';
import '../widgets/auth_text_field.dart';
import '../../account_security_providers.dart';
import '../session_controller.dart';
import '../widgets/auth_error_label.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/social_buttons.dart';

final connectionsProvider = FutureProvider(
  (ref) => ref.watch(accountSecurityProvider).connections(),
);

class AccountConnectionsScreen extends ConsumerStatefulWidget {
  const AccountConnectionsScreen({super.key});
  @override
  ConsumerState<AccountConnectionsScreen> createState() =>
      _AccountConnectionsScreenState();
}

class _AccountConnectionsScreenState
    extends ConsumerState<AccountConnectionsScreen> {
  final password = TextEditingController(),
      confirmation = TextEditingController();
  String? error;
  bool busy = false;
  bool needsRecentLogin = false;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> perform(bool link) async {
    if (busy) return;
    if (!link &&
        (password.text.length < 8 ||
            password.text.length > 128 ||
            password.text != confirmation.text)) {
      setState(
        () => error = AppLocalizations.of(context)!.authPasswordMismatch,
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      needsRecentLogin = false;
    });
    try {
      await ref
          .read(accountSecurityProvider)
          .request(
            link ? '/auth/social/link' : '/auth/first-password',
            link
                ? ref.read(pendingSocialLinkProvider)
                : {'password': password.text},
          );
      if (!mounted) return;
      if (!link) {
        password.clear();
        confirmation.clear();
      }
      if (link) ref.read(pendingSocialLinkProvider.notifier).state = null;
      ref.read(postAuthRouteProvider.notifier).state = null;
      ref.invalidate(connectionsProvider);
      await ref.read(sessionControllerProvider.notifier).refreshAccount();
    } catch (e) {
      if (mounted) {
        setState(() {
          needsRecentLogin =
              e is AccountSecurityException && e.code == 'reauth_required';
          error = authFeedback(context, e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signInAgain() async {
    setState(() => busy = true);
    try {
      final flow = ref.read(pendingSocialLinkProvider);
      await ref.read(sessionControllerProvider.notifier).signOut();
      if (!mounted) return;
      ref.read(pendingSocialLinkProvider.notifier).state = flow;
      context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) setState(() => error = authFeedback(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final info = ref.watch(connectionsProvider);
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final pending = ref.watch(pendingSocialLinkProvider) != null;
    final onboarding =
        ref.watch(postAuthRouteProvider) == AppRoutes.accountConnections;
    final data = info.valueOrNull;
    final providers = data?['providers'] as List? ?? const [];
    final hasGoogle = providers.contains('google');
    final needsPassword = data?['has_password'] == false;
    return Scaffold(
      appBar: AppBar(title: Text(s.authConnections)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.space.s5),
          children: [
            if (error != null) ...[
              AuthErrorLabel(message: error),
              SizedBox(height: tokens.space.s3),
            ],
            if (needsRecentLogin)
              DcoButton(
                label: s.signIn,
                onPressed: busy ? null : signInAgain,
                variant: DcoButtonVariant.secondary,
              ),
            if (pending) ...[
              DcoButton(
                label: s.authFinishLink,
                onPressed: busy ? null : () => perform(true),
                loading: busy,
              ),
              SizedBox(height: tokens.space.s5),
            ],
            if (data == null)
              if (info.hasError)
                DcoButton(
                  label: s.retry,
                  onPressed: () => ref.invalidate(connectionsProvider),
                  variant: DcoButtonVariant.secondary,
                )
              else
                const LinearProgressIndicator()
            else ...[
              DcoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Google', style: theme.textTheme.titleMedium),
                    SizedBox(height: tokens.space.s2),
                    if (hasGoogle)
                      Text(s.authLinked, style: theme.textTheme.bodyMedium)
                    else
                      SocialButtons(
                        connect: true,
                        onConnected: () => ref.invalidate(connectionsProvider),
                      ),
                  ],
                ),
              ),
              if (providers.contains('apple')) ...[
                SizedBox(height: tokens.space.s3),
                DcoCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Apple'),
                    subtitle: Text(s.authLinked),
                  ),
                ),
              ],
              if (needsPassword) ...[
                SizedBox(height: tokens.space.s5),
                Text(s.authFirstPassword, style: theme.textTheme.titleLarge),
                SizedBox(height: tokens.space.s3),
                if (user?.emailVerified == true)
                  AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthTextField(
                          label: s.passwordLabel,
                          controller: password,
                          obscureText: true,
                          enabled: !busy,
                          icon: Icons.lock_outline,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                        ),
                        SizedBox(height: tokens.space.s3),
                        AuthTextField(
                          label: s.confirmPasswordLabel,
                          controller: confirmation,
                          obscureText: true,
                          enabled: !busy,
                          icon: Icons.lock_outline,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => perform(false),
                        ),
                        SizedBox(height: tokens.space.s4),
                        DcoButton(
                          label: s.save,
                          onPressed: busy ? null : () => perform(false),
                          loading: busy && !pending,
                        ),
                      ],
                    ),
                  )
                else if (user?.email.isNotEmpty == true)
                  DcoButton(
                    label: s.authVerifyTitle,
                    onPressed: () => context.push(AppRoutes.verifyEmail),
                    variant: DcoButtonVariant.secondary,
                  ),
              ],
            ],
            if (onboarding || pending) ...[
              SizedBox(height: tokens.space.s4),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        ref.read(postAuthRouteProvider.notifier).state = null;
                        context.go(AppRoutes.dashboard);
                      },
                child: Text(s.authLater),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

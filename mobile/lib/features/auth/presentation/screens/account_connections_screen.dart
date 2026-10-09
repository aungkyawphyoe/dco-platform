import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../generated/app_localizations.dart';
import '../../account_security_providers.dart';
import '../session_controller.dart';
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
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> perform(bool link) async {
    if (!link &&
        (password.text.length < 8 || password.text != confirmation.text)) {
      setState(
        () => error = AppLocalizations.of(context)!.authPasswordMismatch,
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
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
      if (link) ref.read(pendingSocialLinkProvider.notifier).state = null;
      ref.read(postAuthRouteProvider.notifier).state = null;
      ref.invalidate(connectionsProvider);
      await ref.read(sessionControllerProvider.notifier).refreshAccount();
    } catch (e) {
      if (mounted) setState(() => error = authFeedback(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final info = ref.watch(connectionsProvider);
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    return Scaffold(
      appBar: AppBar(title: Text(s.authConnections)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (info.hasError)
              TextButton(
                onPressed: () => ref.invalidate(connectionsProvider),
                child: Text(s.retry),
              ),
            for (final provider
                in (info.valueOrNull?['providers'] as List? ?? []))
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text('$provider'),
                subtitle: Text(s.authLinked),
              ),
            SocialButtons(
              connect: true,
              onConnected: () => ref.invalidate(connectionsProvider),
            ),
            if (ref.watch(pendingSocialLinkProvider) != null)
              FilledButton(
                onPressed: busy ? null : () => perform(true),
                child: Text(s.authFinishLink),
              ),
            if (user?.emailVerified == false)
              TextButton(
                onPressed: () => context.push(AppRoutes.verifyEmail),
                child: Text(s.authVerifyTitle),
              ),
            if (info.valueOrNull?['has_password'] == false &&
                user?.emailVerified == true) ...[
              TextField(
                controller: password,
                decoration: InputDecoration(labelText: s.passwordLabel),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
              ),
              TextField(
                controller: confirmation,
                decoration: InputDecoration(labelText: s.confirmPasswordLabel),
                obscureText: true,
              ),
              FilledButton(
                onPressed: busy ? null : () => perform(false),
                child: Text(s.authFirstPassword),
              ),
            ],
            if (busy) const LinearProgressIndicator(),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final flow = ref.read(pendingSocialLinkProvider);
                      await ref
                          .read(sessionControllerProvider.notifier)
                          .signOut();
                      ref.read(pendingSocialLinkProvider.notifier).state = flow;
                      if (context.mounted) context.go(AppRoutes.login);
                    },
              child: Text(s.authRecentLogin),
            ),
            TextButton(
              onPressed: () {
                ref.read(postAuthRouteProvider.notifier).state = null;
                context.go(AppRoutes.dashboard);
              },
              child: Text(s.authLater),
            ),
          ],
        ),
      ),
    );
  }
}

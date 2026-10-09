import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../generated/app_localizations.dart';
import '../../account_security_providers.dart';
import '../session_controller.dart';
import 'auth_feedback.dart';

class SocialButtons extends ConsumerStatefulWidget {
  const SocialButtons({super.key, this.connect = false, this.onConnected});
  final bool connect;
  final VoidCallback? onConnected;
  @override
  ConsumerState<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends ConsumerState<SocialButtons> {
  bool busy = false;
  String? error;
  Future<void> run(String provider) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(accountSecurityProvider);
      final flow = await api.authorize(provider);
      if (!mounted) return;
      if (widget.connect) {
        ref.read(pendingSocialLinkProvider.notifier).state = flow;
        await api.request('/auth/social/link', flow);
        ref.read(pendingSocialLinkProvider.notifier).state = null;
        await ref.read(sessionControllerProvider.notifier).refreshAccount();
        widget.onConnected?.call();
        return;
      }
      var result = await api.request('/auth/social/complete', flow);
      if (!mounted) return;
      if (result['needs_account_choice'] == true) {
        final s = AppLocalizations.of(context)!;
        final create = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.authAccountChoice),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.authExistingAccount),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.authNewAccount),
              ),
            ],
          ),
        );
        if (create == null || !mounted) return;
        if (!create) {
          ref.read(pendingSocialLinkProvider.notifier).state = flow;
          context.go(AppRoutes.login);
          return;
        }
        try {
          result = await api.request('/auth/social/complete', {
            ...flow,
            'create_account': true,
          });
        } catch (_) {
          ref.read(pendingSocialLinkProvider.notifier).state = flow;
          rethrow;
        }
      }
      await ref
          .read(sessionControllerProvider.notifier)
          .acceptSocialSession(result);
    } catch (e) {
      if (mounted) setState(() => error = authFeedback(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null && error!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        OutlinedButton(
          onPressed: busy ? null : () => run('google'),
          child: Text(widget.connect ? s.authConnectGoogle : s.authGoogle),
        ),
        OutlinedButton(
          onPressed: busy ? null : () => run('apple'),
          child: Text(widget.connect ? s.authConnectApple : s.authApple),
        ),
        if (busy) const LinearProgressIndicator(),
      ],
    );
  }
}

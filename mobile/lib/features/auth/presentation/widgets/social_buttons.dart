import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../core/theme/dco_tokens.dart';
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
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null && error!.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.space.s3),
            child: Text(
              error!,
              style: TextStyle(color: tokens.status.dangerFg),
            ),
          ),
        if (busy) ...[
          LinearProgressIndicator(minHeight: 2),
          SizedBox(height: tokens.space.s3),
        ],
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SocialTile(
                key: const Key('social-google'),
                label: widget.connect ? s.authConnectGoogle : s.authGoogle,
                showLabel: widget.connect,
                asset: 'assets/auth/google.svg',
                onTap: busy ? null : () => run('google'),
              ),
              SizedBox(width: tokens.space.s3),
              _SocialTile(
                key: const Key('social-apple'),
                label: widget.connect ? s.authConnectApple : s.authApple,
                showLabel: widget.connect,
                asset: 'assets/auth/apple.svg',
                monochrome: true,
                onTap: busy ? null : () => run('apple'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({
    super.key,
    required this.label,
    required this.asset,
    required this.onTap,
    this.showLabel = false,
    this.monochrome = false,
  });

  final String label;
  final String asset;
  final VoidCallback? onTap;
  final bool showLabel;
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final icon = SvgPicture.asset(
      asset,
      width: 26,
      height: 26,
      colorFilter: monochrome
          ? ColorFilter.mode(tokens.text.primary, BlendMode.srcIn)
          : null,
    );
    final radius = BorderRadius.circular(tokens.radius.md);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Container(
            width: showLabel ? 96 : 64,
            padding: EdgeInsets.symmetric(
              vertical: showLabel ? tokens.space.s3 : tokens.space.s4,
              horizontal: tokens.space.s2,
            ),
            decoration: BoxDecoration(
              color: tokens.background.card,
              borderRadius: radius,
              border: Border.all(color: tokens.border.subtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (showLabel) ...[
                  SizedBox(height: tokens.space.s2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.text.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

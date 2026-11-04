import '../../../../core/storage/account_lifecycle.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings sign-out action.
///
/// Confirms a user-requested sign-out, ignores dismissal, and calls the
/// existing session controller exactly once while the request is in flight.
/// Session expiry and required security transitions never use this widget.
class SignOutButton extends ConsumerStatefulWidget {
  const SignOutButton({super.key, this.recovery = false});
  final bool recovery;

  @override
  ConsumerState<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<SignOutButton> {
  bool _signingOut = false;
  bool _waitingForDecision = false;

  Future<void> _confirmAndSignOut() async {
    if (_signingOut) return;
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.recovery
              ? s.settingsClearLocalData
              : s.settingsSignOutConfirmTitle,
        ),
        content: Text(s.settingsSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(
              widget.recovery ? s.settingsClearLocalData : s.settingsSignOut,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      var discard = false;
      while (mounted) {
        try {
          await ref
              .read(sessionControllerProvider.notifier)
              .signOut(discardUnsynced: discard);
          break;
        } on LogoutSyncFailure catch (failure) {
          if (!mounted) return;
          final pending = failure.pending;
          setState(() => _waitingForDecision = true);
          final action = await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(s.settingsSyncBeforeLogout),
              content: Text(
                s.settingsLogoutPendingSummary(
                  pending.items.where((kind) => kind != 'upload').length,
                  pending.items.where((kind) => kind == 'upload').length,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(s.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'retry'),
                  child: Text(s.retry),
                ),
                if (pending.canDiscard)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, 'discard'),
                    child: Text(s.settingsDiscardAndLogout),
                  ),
              ],
            ),
          );
          if (action == null) return;
          if (action == 'discard') {
            if (!mounted) return;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(s.settingsDiscardAndLogout),
                content: Text(s.settingsDiscardLogoutBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(s.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(s.settingsDiscardAndLogout),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            discard = true;
          }
          if (mounted) setState(() => _waitingForDecision = false);
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.settingsSignOutFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
          _waitingForDecision = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return DcoButton(
      label: widget.recovery ? s.settingsClearLocalData : s.settingsSignOut,
      variant: DcoButtonVariant.destructive,
      loading: _signingOut && !_waitingForDecision,
      onPressed: _signingOut ? null : _confirmAndSignOut,
    );
  }
}

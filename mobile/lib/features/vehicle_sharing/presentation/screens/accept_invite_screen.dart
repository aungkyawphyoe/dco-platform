import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../generated/app_localizations.dart';
import '../../providers.dart';

/// Landing screen for an emailed share link
/// (`/vehicle/share/accept?token=…`).
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

enum _InviteState { idle, working, accepted, declined, failed }

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  _InviteState _state = _InviteState.idle;
  Object? _error;

  Future<void> _accept() async {
    setState(() {
      _state = _InviteState.working;
      _error = null;
    });
    try {
      await ref
          .read(vehicleShareRepositoryProvider)
          .acceptInvite(widget.token);
      ref.invalidate(sharedVehiclesProvider);
      setState(() => _state = _InviteState.accepted);
    } catch (error) {
      setState(() {
        _state = _InviteState.failed;
        _error = error;
      });
    }
  }

  Future<void> _decline() async {
    setState(() {
      _state = _InviteState.working;
      _error = null;
    });
    try {
      await ref
          .read(vehicleShareRepositoryProvider)
          .declineInvite(widget.token);
      ref.invalidate(sharedVehiclesProvider);
      setState(() => _state = _InviteState.declined);
    } catch (error) {
      setState(() {
        _state = _InviteState.failed;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(s.shareAcceptTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.all(tokens.space.s5),
              child: switch (_state) {
                _InviteState.working => CircularProgressIndicator(
                  color: tokens.text.accent,
                ),
                _InviteState.accepted => _Result(
                  icon: Icons.check_circle_outline,
                  title: s.shareAccepted,
                  body: s.shareAcceptedBody,
                  actionLabel: s.garageMyGarage,
                  onAction: () => context.go(AppRoutes.dashboard),
                ),
                _InviteState.declined => _Result(
                  icon: Icons.link_off,
                  title: s.shareDeclined,
                  body: s.shareDeclinedBody,
                  actionLabel: s.garageMyGarage,
                  onAction: () => context.go(AppRoutes.dashboard),
                ),
                _InviteState.failed => DcoEmptyState(
                  title: _isInvalid ? s.shareAcceptInvalid : s.shareAcceptFailed,
                  body: _error?.toString() ?? '',
                  actionLabel: s.retry,
                  onAction: _accept,
                ),
                _InviteState.idle => _Prompt(onAccept: _accept, onDecline: _decline),
              },
            ),
          ),
        ),
      ),
    );
  }

  bool get _isInvalid {
    final text = _error?.toString() ?? '';
    return text.contains('invalid') ||
        text.contains('not_found') ||
        text.contains('expired');
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.directions_car_outlined,
          size: 72,
          color: tokens.icon.inactive,
        ),
        SizedBox(height: tokens.space.s4),
        Text(
          s.shareAcceptTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: tokens.text.primary,
          ),
        ),
        SizedBox(height: tokens.space.s3),
        Text(
          s.shareAcceptIntro,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
        ),
        SizedBox(height: tokens.space.s6),
        DcoButton(label: s.shareAccept, onPressed: onAccept),
        SizedBox(height: tokens.space.s3),
        DcoButton(
          label: s.shareDecline,
          variant: DcoButtonVariant.tertiary,
          onPressed: onDecline,
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 72, color: tokens.icon.active),
        SizedBox(height: tokens.space.s4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: tokens.text.primary,
          ),
        ),
        SizedBox(height: tokens.space.s3),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
        ),
        SizedBox(height: tokens.space.s6),
        DcoButton(label: actionLabel, onPressed: onAction),
      ],
    );
  }
}

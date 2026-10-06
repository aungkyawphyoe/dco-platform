import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../generated/app_localizations.dart';
import '../../providers.dart';
import '../widgets/share_access_level.dart';

/// Code/QR join flow (`/vehicle/share/join?code=…`). The code may arrive
/// pre-filled from a scanned QR; otherwise it is typed in.
class JoinByCodeScreen extends ConsumerStatefulWidget {
  const JoinByCodeScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinByCodeScreen> createState() => _JoinByCodeScreenState();
}

enum _JoinState { editing, working, joined }

class _JoinByCodeScreenState extends ConsumerState<JoinByCodeScreen> {
  late final TextEditingController _controller;
  _JoinState _state = _JoinState.editing;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _code => _controller.text.trim().toUpperCase();

  bool get _ready => _code.length == 8;

  void _onChanged(String _) => setState(() => _error = null);

  Future<void> _join() async {
    if (!_ready) {
      setState(() => _error = 'invalid');
      return;
    }
    setState(() {
      _state = _JoinState.working;
      _error = null;
    });
    try {
      await ref.read(vehicleShareRepositoryProvider).joinByCode(_code);
      ref.invalidate(sharedVehiclesProvider);
      setState(() => _state = _JoinState.joined);
    } catch (error) {
      setState(() {
        _state = _JoinState.editing;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    if (_state == _JoinState.joined) {
      return Scaffold(
        appBar: AppBar(title: Text(s.shareJoinTitle)),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.space.s5),
            child: DcoEmptyState(
              title: s.shareJoined,
              body: s.shareAcceptedBody,
              actionLabel: s.garageMyGarage,
              onAction: () => context.go(AppRoutes.dashboard),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.shareJoinTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(tokens.space.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.shareJoinBody,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
                  ),
                  SizedBox(height: tokens.space.s4),
                  TextField(
                    controller: _controller,
                    autofocus: widget.initialCode == null,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    onChanged: _onChanged,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      UpperCaseFormatter(),
                    ],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'IBM Plex Mono',
                      letterSpacing: 6,
                      color: tokens.text.primary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: s.shareJoinHint,
                      labelText: s.shareJoinLabel,
                    ),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: tokens.space.s2),
                    Text(
                      _error == 'invalid' ? s.shareJoinUnknownCode : s.shareJoinInvalid,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.status.dangerFg,
                      ),
                    ),
                  ],
                  SizedBox(height: tokens.space.s4),
                  _Preview(code: _code),
                  SizedBox(height: tokens.space.s4),
                  DcoButton(
                    label: _state == _JoinState.working
                        ? s.shareJoining
                        : s.shareJoinAction,
                    loading: _state == _JoinState.working,
                    onPressed: _ready ? _join : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    if (code.length != 8) return const SizedBox.shrink();

    final preview = ref.watch(sharePreviewProvider(code));

    return preview.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (value) {
        if (value == null) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.all(tokens.space.s3),
          decoration: BoxDecoration(
            color: tokens.background.card,
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(color: tokens.border.defaultColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row(
                label: s.shareJoinPreviewVehicle,
                value: value.vehicleNickname,
                mono: false,
              ),
              _Row(label: s.vehicleDetailPlate, value: value.licensePlate, mono: true),
              if (value.ownerDisplayName != null)
                _Row(label: s.shareJoinPreviewOwner, value: value.ownerDisplayName!),
              Row(
                children: [
                  Text(
                    '${s.shareJoinPreviewAccess}: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.secondary,
                    ),
                  ),
                  ShareAccessBadge(accessLevel: value.accessLevel),
                ],
              ),
              _Row(
                label: s.shareExpiresAt,
                value: DateFormat.yMMMd().add_jm().format(value.expiresAt),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.secondary),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.text.primary,
                fontFamily: mono ? 'IBM Plex Mono' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

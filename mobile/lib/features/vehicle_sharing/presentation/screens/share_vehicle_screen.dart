import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/vehicle_share.dart';
import '../../providers.dart';
import '../widgets/share_access_level.dart';
import '../widgets/share_code_panel.dart';

/// Owner entry point for giving someone else access to a vehicle.
///
/// Two methods, matching the plan: invite by email, or hand out a
/// share code + QR.
class ShareVehicleScreen extends ConsumerStatefulWidget {
  const ShareVehicleScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<ShareVehicleScreen> createState() => _ShareVehicleScreenState();
}

class _ShareVehicleScreenState extends ConsumerState<ShareVehicleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _emailController = TextEditingController();
  ShareAccessLevel _accessLevel = ShareAccessLevel.view;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    final s = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = s.shareEmailRequired);
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = s.shareEmailInvalid);
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await ref
          .read(vehicleShareRepositoryProvider)
          .createShare(
            vehicleId: widget.vehicleId,
            method: ShareMethod.email,
            email: email,
            accessLevel: _accessLevel,
          );
      ref.invalidate(vehicleSharesProvider(widget.vehicleId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.shareInviteSent(email))),
      );
      _emailController.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error, s));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _generateCode() async {
    final s = AppLocalizations.of(context)!;
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await ref
          .read(vehicleShareRepositoryProvider)
          .createShare(
            vehicleId: widget.vehicleId,
            method: ShareMethod.codeQr,
            accessLevel: _accessLevel,
          );
      ref.invalidate(vehicleSharesProvider(widget.vehicleId));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error, s));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _regenerateCode() async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.shareRegenerateTitle),
        content: Text(s.shareRegenerateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.shareRegenerateAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _generateCode();
  }

  String _messageFor(Object error, AppLocalizations s) {
    final text = error.toString();
    if (text.contains('share_limit_reached')) {
      final limit =
          ref.read(vehicleSharesProvider(widget.vehicleId)).valueOrNull
              ?.limits.perVehicle ??
          5;
      return s.sharePlanLimitReached(limit);
    }
    if (text.contains('already_shared')) return s.shareAlreadyShared;
    return s.shareErrorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final sharesAsync = ref.watch(vehicleSharesProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.shareVehicleTitle),
        bottom: TabBar(
          controller: _tabController,
          labelColor: tokens.text.accent,
          unselectedLabelColor: tokens.text.tertiary,
          indicatorColor: tokens.text.accent,
          tabs: [
            Tab(text: s.shareEmailTab),
            Tab(text: s.shareCodeTab),
          ],
        ),
      ),
      body: sharesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(vehicleSharesProvider(widget.vehicleId)),
        ),
        data: (detail) => TabBarView(
          controller: _tabController,
          children: [
            _EmailTab(
              controller: _emailController,
              accessLevel: _accessLevel,
              error: _error,
              sending: _sending,
              onAccessLevelChanged: (level) =>
                  setState(() => _accessLevel = level),
              onSubmit: _sendInvitation,
            ),
            ShareCodePanel(
              detail: detail,
              loading: _sending,
              onGenerate: _generateCode,
              onRegenerate: _regenerateCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailTab extends StatelessWidget {
  const _EmailTab({
    required this.controller,
    required this.accessLevel,
    required this.error,
    required this.sending,
    required this.onAccessLevelChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final ShareAccessLevel accessLevel;
  final String? error;
  final bool sending;
  final ValueChanged<ShareAccessLevel> onAccessLevelChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: s.shareEmailLabel,
              hintText: s.shareEmailHint,
              errorText: error,
            ),
          ),
          SizedBox(height: tokens.space.s4),
          ShareAccessLevelField(
            value: accessLevel,
            onChanged: onAccessLevelChanged,
          ),
          SizedBox(height: tokens.space.s4),
          DcoButton(
            label: s.shareSendInvite,
            loading: sending,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

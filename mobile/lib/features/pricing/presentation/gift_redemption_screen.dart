import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/dco_card.dart';
import '../../../core/gating/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/dco_tokens.dart';
import '../../../core/widgets/dco_button.dart';
import '../../../core/providers.dart';
import '../../../features/fleet/providers.dart';
import '../../../generated/app_localizations.dart';
import '../domain/pricing.dart';
import '../providers.dart';

class GiftRedemptionScreen extends ConsumerStatefulWidget {
  const GiftRedemptionScreen({super.key});
  @override
  ConsumerState<GiftRedemptionScreen> createState() =>
      _GiftRedemptionScreenState();
}

class _GiftRedemptionScreenState extends ConsumerState<GiftRedemptionScreen> {
  final _code = TextEditingController();
  bool _refreshing = false, _redeeming = false;
  bool _refreshFailed = false;
  String? _messageKey;
  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });
    try {
      await ref.read(pricingRepositoryProvider).refresh();
      await ref
          .read(licenseControllerProvider.notifier)
          .refreshIfStale(force: true);
      if (mounted && _messageKey == 'license_pending') {
        final gift = ref.read(subscriptionStatusProvider).valueOrNull?.gift;
        final license = ref.read(licenseControllerProvider).valueOrNull;
        if (gift != null && license?.planId == gift.plan) {
          setState(() => _messageKey = 'success');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _refreshFailed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _redeem() async {
    if (_code.text.trim().isEmpty || _redeeming) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _redeeming = true;
      _messageKey = null;
    });
    try {
      final gift = await ref.read(pricingRepositoryProvider).redeem(_code.text);
      if (!mounted) return;
      await ref
          .read(licenseControllerProvider.notifier)
          .refreshIfStale(force: true);
      if (!mounted) return;
      ref.invalidate(entitlementsProvider);
      unawaited(ref.read(refreshAccountProfileProvider)().catchError((_) {}));
      final license = ref.read(licenseControllerProvider).valueOrNull;
      setState(() {
        _messageKey = !gift.endsAt.isAfter(DateTime.now().toUtc())
            ? 'ended'
            : license?.planId == gift.plan
            ? 'success'
            : 'license_pending';
        _code.clear();
      });
    } on RedemptionFailure catch (e) {
      if (mounted) setState(() => _messageKey = e.code);
    } catch (_) {
      if (mounted) setState(() => _messageKey = 'unavailable');
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _message(AppLocalizations s) => switch (_messageKey) {
    'success' => s.pricingSuccess,
    'ended' => s.pricingEnded,
    'license_pending' => s.pricingLicensePending,
    'email_verification_required' => s.pricingVerify,
    'gift_active' => s.pricingActiveGift,
    'plan_ineligible' => s.pricingIneligible,
    'promotion_redeemed' => s.pricingAlreadyRedeemed,
    'code_unavailable' || 'validation' => s.pricingUnavailable,
    'rate_limited' => s.pricingRateLimited,
    _ => s.pricingNetworkError,
  };

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final subscription = ref.watch(subscriptionStatusProvider).valueOrNull;
    final license = ref.watch(licenseControllerProvider).valueOrNull;
    final user = ref.watch(authUserProvider);
    final gift = subscription?.gift;
    final activeGift =
        gift != null && gift.endsAt.isAfter(DateTime.now().toUtc());
    final currentPlan = gift != null && !activeGift
        ? 'free'
        : subscription?.plan ?? license?.planId ?? user?.plan ?? 'free';
    final verified = user?.emailVerified == true;
    final completed =
        _messageKey == 'success' || _messageKey == 'license_pending';
    final canRedeem =
        verified && currentPlan == 'free' && !activeGift && !completed;
    final success = _messageKey == 'success';

    return Scaffold(
      appBar: AppBar(title: Text(s.pricingRedeem)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(t.space.s5),
          children: [
            if (_refreshing) const LinearProgressIndicator(),
            SizedBox(height: t.space.s6),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: success ? t.status.successBg : t.background.navActive,
                  shape: BoxShape.circle,
                  boxShadow: t.shadows.card,
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.redeem_rounded,
                  size: 40,
                  color: success ? t.status.successFg : t.icon.active,
                ),
              ),
            ),
            SizedBox(height: t.space.s5),
            Text(
              success ? s.pricingGiftReady : s.pricingGiftWelcome,
              textAlign: TextAlign.center,
              style: text.displaySmall,
            ),
            SizedBox(height: t.space.s2),
            Text(
              s.pricingGiftIntro,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: t.text.secondary),
            ),
            SizedBox(height: t.space.s6),
            DcoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!verified) ...[
                    Text(s.pricingVerify),
                    SizedBox(height: t.space.s4),
                    DcoButton(
                      label: s.authVerifyTitle,
                      onPressed: () async {
                        await context.push(AppRoutes.verifyEmail);
                        if (mounted) _refresh();
                      },
                    ),
                  ] else if (!completed && activeGift)
                    Text(s.pricingActiveGift)
                  else if (!completed && currentPlan != 'free')
                    Text(s.pricingIneligible),
                  if (canRedeem) ...[
                    TextField(
                      controller: _code,
                      enabled: !_redeeming,
                      maxLength: 64,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: s.pricingCode,
                        hintText: 'AUTOX-…',
                        prefixIcon: const Icon(
                          Icons.confirmation_number_outlined,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _redeem(),
                    ),
                    SizedBox(height: t.space.s4),
                    DcoButton(
                      key: const ValueKey('gift-submit'),
                      label: s.pricingRedeem,
                      loading: _redeeming,
                      onPressed: _code.text.trim().isEmpty ? null : _redeem,
                    ),
                  ],
                  if (_messageKey != null) ...[
                    if (canRedeem) SizedBox(height: t.space.s4),
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            success
                                ? Icons.check_circle_outline
                                : completed
                                ? Icons.sync
                                : Icons.info_outline,
                            color: success
                                ? t.status.successFg
                                : t.status.infoFg,
                          ),
                          SizedBox(width: t.space.s2),
                          Expanded(child: Text(_message(s))),
                        ],
                      ),
                    ),
                  ],
                  if (_messageKey == 'license_pending' || _refreshFailed) ...[
                    if (_refreshFailed) Text(s.pricingOffline),
                    TextButton(
                      onPressed: _refreshing ? null : _refresh,
                      child: Text(s.pricingRetry),
                    ),
                  ],
                  if (completed) ...[
                    SizedBox(height: t.space.s4),
                    DcoButton(
                      label: s.pricingBackToPlans,
                      variant: DcoButtonVariant.secondary,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: t.space.s5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: t.text.caption,
                ),
                SizedBox(width: t.space.s2),
                Expanded(
                  child: Text(
                    s.pricingGiftTerms,
                    style: text.bodySmall?.copyWith(color: t.text.caption),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

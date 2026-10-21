import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/gating/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/dco_tokens.dart';
import '../../../core/widgets/dco_button.dart';
import '../../../core/providers.dart';
import '../../../features/fleet/providers.dart';
import '../../../generated/app_localizations.dart';
import '../domain/pricing.dart';
import '../providers.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});
  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  final _code = TextEditingController();
  bool _annual = false, _refreshing = false, _redeeming = false;
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
    final tokens = context.tokens;
    final plans = ref.watch(pricingPlansProvider);
    final subscription = ref.watch(subscriptionStatusProvider).valueOrNull;
    final license = ref.watch(licenseControllerProvider).valueOrNull;
    final user = ref.watch(authUserProvider);
    final gift = subscription?.gift;
    final giftEnded =
        gift != null && !gift.endsAt.isAfter(DateTime.now().toUtc());
    final currentPlan = giftEnded
        ? 'free'
        : subscription?.plan ?? license?.planId ?? user?.plan ?? 'free';
    final activeGift = gift != null && !giftEnded;
    final verified = user?.emailVerified == true;
    final canRedeem = verified && currentPlan == 'free' && !activeGift;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);

    Widget panel(Widget child) => Container(
      margin: EdgeInsets.only(bottom: tokens.space.s4),
      padding: EdgeInsets.all(tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        border: Border.all(color: tokens.border.defaultColor),
      ),
      child: child,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.pricingTitle),
        actions: [
          IconButton(
            tooltip: s.pricingRetry,
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.all(tokens.space.s4),
          children: [
            if (_refreshing) const LinearProgressIndicator(),
            if (_refreshFailed)
              Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.space.s3),
                child: Text(
                  s.pricingOffline,
                  style: TextStyle(color: tokens.text.secondary),
                ),
              ),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.pricingCurrent,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  SizedBox(height: tokens.space.s2),
                  Text(
                    currentPlan == 'free'
                        ? 'Free'
                        : currentPlan == 'lite'
                        ? 'Lite'
                        : currentPlan == 'standard'
                        ? 'Standard'
                        : currentPlan,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (gift != null) ...[
                    SizedBox(height: tokens.space.s2),
                    Text(
                      giftEnded
                          ? s.pricingEnded
                          : s.pricingGiftEnds(
                              DateFormat.yMMMd(
                                locale,
                              ).add_jm().format(gift.endsAt.toLocal()),
                            ),
                    ),
                    Text(
                      s.pricingGiftTerms,
                      style: TextStyle(color: tokens.text.secondary),
                    ),
                  ],
                ],
              ),
            ),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.pricingGiftTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: tokens.space.s3),
                  if (!verified) ...[
                    Text(s.pricingVerify),
                    TextButton(
                      onPressed: () async {
                        await context.push(AppRoutes.verifyEmail);
                        if (mounted) _refresh();
                      },
                      child: Text(s.authVerifyTitle),
                    ),
                  ] else if (activeGift)
                    Text(s.pricingActiveGift)
                  else if (currentPlan != 'free')
                    Text(s.pricingIneligible),
                  if (canRedeem) ...[
                    TextField(
                      controller: _code,
                      enabled: !_redeeming,
                      maxLength: 64,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: s.pricingCode,
                        prefixIcon: const Icon(Icons.redeem),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _redeem(),
                    ),
                    DcoButton(
                      label: s.pricingRedeem,
                      loading: _redeeming,
                      onPressed: _code.text.trim().isEmpty ? null : _redeem,
                    ),
                    SizedBox(height: tokens.space.s2),
                    Text(s.pricingGiftTerms),
                  ],
                  if (_messageKey != null)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.space.s3),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_message(s)),
                      ),
                    ),
                  if (_messageKey == 'license_pending')
                    TextButton(
                      onPressed: _refreshing ? null : _refresh,
                      child: Text(s.pricingRetry),
                    ),
                ],
              ),
            ),
            Text(
              s.pricingComingSoon,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.space.s3),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(s.pricingMonthly)),
                ButtonSegment(value: true, label: Text(s.pricingAnnual)),
              ],
              selected: {_annual},
              onSelectionChanged: (selection) =>
                  setState(() => _annual = selection.first),
            ),
            SizedBox(height: tokens.space.s4),
            if (plans.isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!plans.isLoading &&
                (plans.valueOrNull == null || plans.valueOrNull!.isEmpty))
              Text(s.pricingNoPlans),
            for (final plan in plans.valueOrNull ?? <PricingPlan>[])
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (plan.id == currentPlan)
                          const Icon(Icons.check_circle_outline),
                      ],
                    ),
                    SizedBox(height: tokens.space.s2),
                    Text(
                      s.pricingPrice(
                        number.format(_annual ? plan.annual : plan.monthly),
                        _annual ? s.pricingAnnual : s.pricingMonthly,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.space.s3),
                    Text(
                      s.pricingVehicleLimit(
                        plan.vehicles == null
                            ? s.pricingUnlimited
                            : number.format(plan.vehicles),
                      ),
                    ),
                    Text(
                      s.pricingShareLimit(
                        plan.sharing == null
                            ? s.pricingUnlimited
                            : number.format(plan.sharing),
                      ),
                    ),
                    Text(
                      s.pricingStorageLimit(
                        number.format(plan.storageBytes ~/ (1024 * 1024)),
                      ),
                    ),
                    SizedBox(height: tokens.space.s2),
                    Text(
                      s.pricingCoreFeatures,
                      style: TextStyle(color: tokens.text.secondary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

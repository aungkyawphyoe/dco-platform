import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/gating/providers.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/dco_tokens.dart';
import '../../../core/widgets/dco_button.dart';
import '../../../core/widgets/dco_card.dart';
import '../../../generated/app_localizations.dart';
import '../domain/pricing.dart';
import '../providers.dart';
import 'widgets/plan_offer_card.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});
  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  String? _selectedPlan;
  bool _annual = false, _refreshing = false, _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });
    try {
      await ref.read(pricingRepositoryProvider).refresh();
      if (!mounted) return;
      await ref
          .read(licenseControllerProvider.notifier)
          .refreshIfStale(force: true);
    } catch (_) {
      if (mounted) setState(() => _refreshFailed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final plans = ref.watch(pricingPlansProvider);
    final options = plans.valueOrNull ?? <PricingPlan>[];
    final subscription = ref.watch(subscriptionStatusProvider).valueOrNull;
    final license = ref.watch(licenseControllerProvider).valueOrNull;
    final user = ref.watch(authUserProvider);
    final gift = subscription?.gift;
    final ended = gift != null && !gift.endsAt.isAfter(DateTime.now().toUtc());
    final current = ended
        ? 'free'
        : subscription?.plan ?? license?.planId ?? user?.plan ?? 'free';
    final currentName = switch (current) {
      'free' => 'Free',
      'lite' => 'Lite',
      'standard' => 'Standard',
      _ => current,
    };
    final selected =
        options
            .where((p) => p.id == (_selectedPlan ?? 'standard'))
            .firstOrNull ??
        options.firstOrNull;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.pricingTitle),
        actions: [
          IconButton(
            tooltip: s.pricingRetry,
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            t.space.s5,
            t.space.s3,
            t.space.s5,
            t.space.s6,
          ),
          children: [
            if (_refreshing) const LinearProgressIndicator(),
            Text(s.pricingHeadline, style: text.displaySmall),
            SizedBox(height: t.space.s2),
            Text(
              s.pricingIntro,
              style: text.bodyMedium?.copyWith(color: t.text.secondary),
            ),
            SizedBox(height: t.space.s4),
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: t.icon.active),
                SizedBox(width: t.space.s2),
                Expanded(
                  child: Text(
                    '${s.pricingCurrent} · $currentName',
                    style: text.labelLarge,
                  ),
                ),
              ],
            ),
            if (gift != null)
              Padding(
                padding: EdgeInsets.only(top: t.space.s2),
                child: Text(
                  ended
                      ? s.pricingEnded
                      : s.pricingGiftEnds(
                          DateFormat.yMMMd(
                            locale,
                          ).add_jm().format(gift.endsAt.toLocal()),
                        ),
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ),
            if (_refreshFailed || plans.hasError)
              Padding(
                padding: EdgeInsets.only(top: t.space.s4),
                child: Text(
                  s.pricingOffline,
                  style: TextStyle(color: t.status.infoFg),
                ),
              ),
            SizedBox(height: t.space.s5),
            if (options.isNotEmpty) ...[
              Row(
                children: [
                  for (final plan in options)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: plan == options.last ? 0 : t.space.s2,
                        ),
                        child: Semantics(
                          button: true,
                          selected: plan.id == selected?.id,
                          child: DcoCard(
                            key: ValueKey('plan-${plan.id}'),
                            padding: EdgeInsets.symmetric(
                              vertical: t.space.s3,
                              horizontal: t.space.s1,
                            ),
                            color: plan.id == selected?.id
                                ? t.background.navActive
                                : t.background.card,
                            onTap: () =>
                                setState(() => _selectedPlan = plan.id),
                            child: Column(
                              children: [
                                Icon(
                                  plan.id == 'free'
                                      ? Icons.directions_car_outlined
                                      : plan.id == 'lite'
                                      ? Icons.garage_outlined
                                      : Icons.garage_rounded,
                                  size: 22,
                                  color: plan.id == selected?.id
                                      ? t.icon.active
                                      : t.icon.inactive,
                                ),
                                SizedBox(height: t.space.s1),
                                Text(
                                  plan.name,
                                  textAlign: TextAlign.center,
                                  style: text.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: t.space.s5),
            ],
            if (plans.isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!plans.isLoading && options.isEmpty)
              DcoCard(
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined),
                    SizedBox(height: t.space.s3),
                    Text(s.pricingNoPlans),
                    TextButton(
                      onPressed: _refresh,
                      child: Text(s.pricingRetry),
                    ),
                  ],
                ),
              ),
            if (selected != null) ...[
              PlanOfferCard(
                plan: selected,
                annual: _annual,
                isCurrent: selected.id == current,
              ),
              SizedBox(height: t.space.s5),
              if (selected.monthly > 0) ...[
                Text(s.pricingComparePeriods, style: text.titleMedium),
                SizedBox(height: t.space.s3),
                _BillingOption(
                  title: s.pricingMonthly,
                  amount: '${number.format(selected.monthly)} MMK',
                  caption: s.pricingMonthlyPrice,
                  selected: !_annual,
                  onTap: () => setState(() => _annual = false),
                ),
                SizedBox(height: t.space.s3),
                _BillingOption(
                  title: s.pricingAnnual,
                  amount: '${number.format(selected.annual)} MMK',
                  caption: selected.monthly * 12 > selected.annual
                      ? s.pricingAnnualSaving(
                          number.format(
                            selected.monthly * 12 - selected.annual,
                          ),
                        )
                      : s.pricingAnnualPrice,
                  selected: _annual,
                  onTap: () => setState(() => _annual = true),
                ),
                SizedBox(height: t.space.s4),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: t.text.caption,
                  ),
                  SizedBox(width: t.space.s2),
                  Expanded(
                    child: Text(
                      s.pricingComingSoon,
                      style: text.bodySmall?.copyWith(color: t.text.caption),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: t.background.primary),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.s5,
              t.space.s3,
              t.space.s5,
              t.space.s4,
            ),
            child: DcoButton(
              label: s.pricingGiftCta,
              icon: Icons.redeem_rounded,
              onPressed: () async {
                await context.push(AppRoutes.redeemGift);
                if (mounted) _refresh();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BillingOption extends StatelessWidget {
  const _BillingOption({
    required this.title,
    required this.amount,
    required this.caption,
    required this.selected,
    required this.onTap,
  });
  final String title, amount, caption;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: DcoCard(
        padding: EdgeInsets.all(t.space.s4),
        color: selected ? t.background.navActive : t.background.card,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? t.icon.active : t.icon.inactive,
            ),
            SizedBox(width: t.space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.labelLarge),
                  SizedBox(height: t.space.s1),
                  Text(amount, style: text.titleMedium),
                  SizedBox(height: t.space.s1),
                  Text(
                    caption,
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
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

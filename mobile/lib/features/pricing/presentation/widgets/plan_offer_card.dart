import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_card.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/pricing.dart';

class PlanOfferCard extends StatelessWidget {
  const PlanOfferCard({
    super.key,
    required this.plan,
    required this.annual,
    required this.isCurrent,
    this.storePrice,
    this.storeBilling = false,
  });
  final PricingPlan plan;
  final bool annual, isCurrent;
  final String? storePrice;
  final bool storeBilling;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final free = plan.monthly == 0;
    final description = switch (plan.id) {
      'free' => s.pricingFreeDescription,
      'lite' => s.pricingLiteDescription,
      _ => s.pricingStandardDescription,
    };
    return DcoCard(
      emphasized: true,
      padding: EdgeInsets.all(t.space.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: t.space.s3,
            runSpacing: t.space.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(plan.name, style: text.titleLarge),
              if (isCurrent)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.s2,
                    vertical: t.space.s1,
                  ),
                  decoration: BoxDecoration(
                    color: t.background.secondary,
                    borderRadius: BorderRadius.circular(t.radius.full),
                  ),
                  child: Text(
                    s.pricingCurrent,
                    style: text.labelSmall?.copyWith(color: t.text.secondary),
                  ),
                ),
            ],
          ),
          SizedBox(height: t.space.s2),
          Text(
            description,
            style: text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          SizedBox(height: t.space.s5),
          Text(
            storeBilling && !free
                ? (storePrice ?? s.playUnavailablePrice)
                : number.format(annual && !free ? plan.annual : plan.monthly),
            key: const ValueKey('featured-price'),
            style: text.displayLarge?.copyWith(
              fontSize: 36,
              height: 1.15,
              color: t.text.primary,
            ),
          ),
          SizedBox(height: t.space.s1),
          Text(
            free
                ? s.pricingFreeForever
                : '${storeBilling ? '' : 'MMK / '}${annual ? s.pricingAnnual : s.pricingMonthly}',
            style: text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          SizedBox(height: t.space.s5),
          Container(
            padding: EdgeInsets.all(t.space.s4),
            decoration: BoxDecoration(
              color: t.background.primary,
              borderRadius: BorderRadius.circular(t.radius.lg),
            ),
            child: Column(
              children: [
                _Benefit(
                  icon: Icons.directions_car_outlined,
                  title: s.pricingVehicleLimit(
                    plan.vehicles == null
                        ? s.pricingUnlimited
                        : number.format(plan.vehicles),
                  ),
                  description: s.pricingVehicleBenefit,
                ),
                SizedBox(height: t.space.s4),
                _Benefit(
                  icon: Icons.people_outline_rounded,
                  title: s.pricingShareLimit(
                    plan.sharing == null
                        ? s.pricingUnlimited
                        : number.format(plan.sharing),
                  ),
                  description: s.pricingShareBenefit,
                ),
                SizedBox(height: t.space.s4),
                _Benefit(
                  icon: Icons.cloud_outlined,
                  title: s.pricingStorageLimit(
                    number.format(plan.storageBytes ~/ (1024 * 1024)),
                  ),
                  description: s.pricingStorageBenefit,
                ),
              ],
            ),
          ),
          SizedBox(height: t.space.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: t.status.successFg,
              ),
              SizedBox(width: t.space.s2),
              Expanded(
                child: Text(
                  s.pricingCoreFeatures,
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: t.background.card,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: t.icon.inactive),
        ),
        SizedBox(width: t.space.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.labelLarge?.copyWith(color: t.text.primary),
              ),
              SizedBox(height: t.space.s1),
              Text(
                description,
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

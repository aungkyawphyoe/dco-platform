import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MaintenanceSuccessScreen extends ConsumerWidget {
  const MaintenanceSuccessScreen({super.key, required this.record});

  final ServiceRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final currency = ref.watch(currencyProvider).code;

    final money = MoneyFormat.labeled(record.totalCost, currency);
    final odometer = MileageFormat.labeled(record.odometer, lengthUnit);
    final date = DateFormat.yMMMd().format(record.servicedOn);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(s.registerServiceTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                // Hero success card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                    boxShadow: tokens.shadows.card,
                  ),
                  child: Material(
                    color: tokens.background.card,
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space.s5),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.status.successFg
                                  .withValues(alpha: 0.12),
                              border: Border.all(
                                color: tokens.status.successFg
                                    .withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: tokens.status.successFg,
                              size: 36,
                            ),
                          ),
                          SizedBox(height: tokens.space.s3),
                          Text(
                            s.registerSuccessTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: tokens.space.s2),
                          Text(
                            s.registerSuccessSubtitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.text.secondary,
                                      height: 1.5,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.s4),

                // Logged details card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                    boxShadow: tokens.shadows.card,
                  ),
                  child: Material(
                    color: tokens.background.card,
                    borderRadius: BorderRadius.circular(tokens.radius.lg),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.registerSuccessDetails,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: tokens.space.s3),
                          _kv(context, s.registerServiceJobTitle, record.title),
                          _kv(context, s.registerServiceDate, date),
                          _kv(context, s.registerServiceMileage, odometer),
                          if (record.workshopName != null)
                            _kv(
                              context,
                              s.serviceDetailWorkshop,
                              record.workshopName!,
                            ),
                          SizedBox(height: tokens.space.s3),
                          Text(
                            s.serviceDetailServices,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          SizedBox(height: tokens.space.s2),
                          ...record.items.map((item) {
                            final cost = item.lineCost == null
                                ? '—'
                                : MoneyFormat.labeled(item.lineCost!, currency);
                            return Padding(
                              padding:
                                  EdgeInsets.only(bottom: tokens.space.s2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                  Text(
                                    cost,
                                    style: GoogleFonts.ibmPlexMono(
                                      color: tokens.text.secondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (record.parts.isNotEmpty) ...[
                            SizedBox(height: tokens.space.s3),
                            Text(
                              s.serviceDetailParts,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            SizedBox(height: tokens.space.s2),
                            ...record.parts.map(
                              (part) => Padding(
                                padding:
                                    EdgeInsets.only(bottom: tokens.space.s2),
                                child: Text(
                                  part.name,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: tokens.space.s3),
                          const Divider(),
                          SizedBox(height: tokens.space.s3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                s.serviceDetailTotal,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                money,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: tokens.text.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          if (record.notes != null &&
                              record.notes!.trim().isNotEmpty) ...[
                            SizedBox(height: tokens.space.s3),
                            Text(
                              s.serviceDetailNotes,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            SizedBox(height: tokens.space.s1),
                            Text(
                              record.notes!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: tokens.text.secondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.s4),
              ],
            ),
          ),
          // Back to Home CTA
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space.s4,
              tokens.space.s2,
              tokens.space.s4,
              MediaQuery.paddingOf(context).bottom + tokens.space.s4,
            ),
            child: DcoButton(
              label: s.registerSuccessBackHome,
              onPressed: () => context.go(AppRoutes.dashboard),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

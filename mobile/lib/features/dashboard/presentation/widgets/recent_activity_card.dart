import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/providers.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RecentActivityCard extends ConsumerWidget {
  const RecentActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final services = ref.watch(maintenanceHistoryProvider);
    final fuel = ref.watch(vehicleFuelLogsProvider);
    final expenses = ref.watch(vehicleExpensesProvider);
    final currency = ref.watch(currencyProvider).code;
    if (services.hasError || fuel.hasError || expenses.hasError) {
      return DcoCard(
        child: Column(
          children: [
            Text(s.dashboardActivityLoadError),
            TextButton(
              onPressed: () {
                ref.invalidate(maintenanceHistoryProvider);
                ref.invalidate(vehicleFuelLogsProvider);
                ref.invalidate(vehicleExpensesProvider);
              },
              child: Text(s.retry),
            ),
          ],
        ),
      );
    }
    if (!services.hasValue || !fuel.hasValue || !expenses.hasValue) {
      return const DcoCard(child: Center(child: CircularProgressIndicator()));
    }
    // Auto-created expenses share their source service/refuel record ID.
    final sourceRecordIds = {
      for (final record in services.requireValue) record.id,
      for (final record in fuel.requireValue) record.id,
    };
    final activities =
        [
          for (final record in services.requireValue)
            (
              date: record.servicedOn,
              created: record.createdAt,
              title: record.title,
              amount: record.totalCost,
              route: AppRoutes.serviceDetail(record.id),
              icon: Icons.build_outlined,
              color: tokens.chart.maintenance,
            ),
          for (final record in fuel.requireValue)
            (
              date: record.loggedOn,
              created: record.createdAt,
              title: record.fillStatus == 'full'
                  ? '${s.fuelFillFull} - ${record.fuelTypeName}'
                  : record.fuelTypeName,
              amount: record.cost,
              route: AppRoutes.fuelLogDetail(record.id),
              icon: record.kind == FuelLogKind.charge
                  ? Icons.bolt_outlined
                  : Icons.local_gas_station_outlined,
              color: tokens.chart.fuel,
            ),
          for (final record in expenses.requireValue.where(
            (record) => !sourceRecordIds.contains(record.id),
          ))
            (
              date: record.incurredOn,
              created: record.createdAt,
              title:
                  record.notesPreview ??
                  switch (record.category) {
                    ExpenseCategory.fuel => s.expenseCategoryFuel,
                    ExpenseCategory.maintenance => s.expenseCategoryMaintenance,
                    ExpenseCategory.insurance => s.expenseCategoryInsurance,
                    ExpenseCategory.parking => s.expenseCategoryParking,
                    ExpenseCategory.tolls => s.expenseCategoryTolls,
                    ExpenseCategory.parts => s.expenseCategoryParts,
                    ExpenseCategory.other => s.expenseCategoryOther,
                  },
              amount: record.amount,
              route: AppRoutes.expenseDetail(record.id),
              icon: Icons.receipt_long_outlined,
              color: tokens.chart.other,
            ),
        ]..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) return byDate;
          final byCreation = b.created.compareTo(a.created);
          return byCreation != 0 ? byCreation : a.route.compareTo(b.route);
        });
    final recent = activities.take(10).toList();
    if (recent.isEmpty) {
      return DcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.dashboardNoActivityYet,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.space.s2),
            Text(
              s.dashboardActivityEmptyBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.caption),
            ),
          ],
        ),
      );
    }
    return DcoCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: Column(
          children: [
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 16,
                  color: tokens.border.divider,
                ),
              Semantics(
                button: true,
                child: InkWell(
                  key: ValueKey(recent[i].route),
                  onTap: () => context.push(recent[i].route),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: recent[i].color.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            recent[i].icon,
                            color: recent[i].color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat.yMMMd().format(recent[i].date),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: tokens.text.caption),
                              ),
                              SizedBox(height: tokens.space.s1),
                              Text(
                                recent[i].title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          MoneyFormat.labeled(recent[i].amount, currency),
                          textAlign: TextAlign.end,
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: tokens.text.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

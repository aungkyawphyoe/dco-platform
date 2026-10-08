import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_access.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/stats/domain/expense_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/stats_models.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:dco_mobile/features/stats/presentation/widgets/stats_charts.dart';
import 'package:dco_mobile/features/stats/presentation/widgets/stats_definitions.dart';
import 'package:dco_mobile/features/stats/presentation/widgets/stats_kpi_grid.dart';
import 'package:dco_mobile/features/stats/presentation/widgets/stats_scaffold.dart';
import 'package:dco_mobile/features/stats/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Expense analytics: category spend, monthly trend, most expensive record
/// (FRD stats.md).
class ExpenseStatsScreen extends ConsumerStatefulWidget {
  const ExpenseStatsScreen({super.key});

  @override
  ConsumerState<ExpenseStatsScreen> createState() => _ExpenseStatsScreenState();
}

class _ExpenseStatsScreenState extends ConsumerState<ExpenseStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analyticsProvider)
          .track(AnalyticsEvent.statsOpened, {'screen': 'expense'});
    });
  }

  void _changePeriod(StatsPeriod period) {
    ref.read(expenseStatsPeriodProvider.notifier).state = period;
    ref.read(analyticsProvider).track(AnalyticsEvent.statsPeriodChanged, {
      'screen': 'expense',
      'year': period.year ?? 'all',
      'month': period.month ?? 'all',
    });
  }

  void _openDefinitions() {
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.statsDefinitionsOpened, {'screen': 'expense'});
    final s = AppLocalizations.of(context)!;
    showStatsDefinitions(
      context,
      title: s.expenseStatsTitle,
      entries: [
        s.statsDefPeriod,
        s.statsDefTotalExpenses,
        s.statsDefTotalCost,
        s.statsDefAvgPerExpense,
        s.statsDefTopCategory,
        s.statsDefMostExpensiveExpense,
        s.statsDefUnits,
        s.statsDefMonthLabel,
        s.statsDefMonthlyCostChart,
        s.statsDefDonutCategory,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final access = VehicleAccess.of(vehicle, ref.watch(currentUserIdProvider));
    final stats = ref.watch(expenseStatsProvider);
    final period = ref.watch(expenseStatsPeriodProvider);
    final currency = ref.watch(currencyProvider).code;

    final body = vehicle == null
        ? DcoEmptyState(
            title: s.statsNoActiveVehicle,
            body: s.statsNoActiveVehicleBody,
          )
        : stats == null
        ? const StatsSkeleton()
        : !stats.hasAnyRecords
        ? DcoEmptyState(
            title: s.expensesEmptyTitle,
            body: s.statsEmptyExpensesBody(vehicle.displayName),
            actionLabel: access.canCreate ? s.expensesAddExpense : null,
            actionKey: const Key('stats-empty-cta'),
            onAction: access.canCreate
                ? () => context.push(AppRoutes.expenseNew)
                : null,
          )
        : !stats.hasRecordsInPeriod
        ? DcoEmptyState(
            title: s.statsNoRecordsPeriod,
            body: s.statsNoRecordsPeriodBody,
            actionLabel: s.statsClearFilters,
            actionKey: const Key('stats-clear-filters'),
            onAction: () => _changePeriod(StatsPeriod.all),
          )
        : StatsScaffold(
            title: s.expenseStatsTitle,
            vehicleName: vehicle.displayName,
            period: period,
            yearOptions: stats.yearOptions,
            monthOptions: stats.monthOptions,
            onPeriodChanged: _changePeriod,
            onOpenDefinitions: _openDefinitions,
            kpis: _kpis(stats, s, currency),
            charts: [
              StatsBarChart(
                title: s.statsMonthlyCost,
                values: stats.monthlyCost,
                color: tokens.chart.insurance,
                summary:
                    '${MoneyFormat.labeled(stats.totalCost, currency)} $currency',
                emptyLabel: s.statsChartNoData,
                selectedYear: period.year,
              ),
              StatsDonutChart(
                title: s.statsCostByCategory,
                donut: stats.donut,
                labelOf: (key) => key == DonutChart.otherKey
                    ? s.statsOther
                    : ExpenseCategory.parse(key).label,
                colorOf: (index, key) => key == DonutChart.otherKey
                    ? tokens.chart.other
                    : _categoryColor(ExpenseCategory.parse(key), tokens),
                valueOf: (slice) => MoneyFormat.labeled(slice.value, currency),
                summary:
                    '${MoneyFormat.labeled(stats.donut.total, currency)} $currency',
                emptyLabel: s.statsChartNoData,
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: Text(s.expenseStatsTitle)),
      body: body,
    );
  }

  List<StatsKpi> _kpis(ExpenseStats stats, AppLocalizations s, String currency) {
    final avgSub = stats.avgPerExpense != null
        ? MoneyFormat.labeled(stats.avgPerExpense!, currency)
        : null;
    final topSub = stats.topCategoryCost != null
        ? MoneyFormat.labeled(stats.topCategoryCost!, currency)
        : null;
    final mostExpensive = stats.mostExpensiveCost != null
        ? MoneyFormat.labeled(stats.mostExpensiveCost!, currency)
        : null;
    final mostExpensiveSub = stats.mostExpensiveOn == null
        ? null
        : stats.mostExpensiveCategory == null
        ? DateFormat.yMMMd().format(stats.mostExpensiveOn!)
        : '${DateFormat.yMMMd().format(stats.mostExpensiveOn!)} · ${stats.mostExpensiveCategory!.label}';

    return [
      StatsKpi(label: s.statsTotalExpenses, value: '${stats.countInPeriod}'),
      StatsKpi(
        label: s.statsTotalCost,
        value: MoneyFormat.labeled(stats.totalCost, currency),
        sub: avgSub,
      ),
      StatsKpi(
        label: s.statsTopCategory,
        value: stats.topCategory?.label,
        sub: topSub,
      ),
      StatsKpi(
        label: s.statsMostExpensiveExpense,
        value: mostExpensive,
        sub: mostExpensiveSub,
      ),
    ];
  }

  Color _categoryColor(ExpenseCategory category, DcoTokens tokens) {
    return switch (category) {
      ExpenseCategory.fuel => tokens.chart.fuel,
      ExpenseCategory.maintenance => tokens.chart.maintenance,
      ExpenseCategory.insurance => tokens.chart.insurance,
      ExpenseCategory.parking => tokens.chart.parking,
      ExpenseCategory.tolls => tokens.chart.tolls,
      ExpenseCategory.parts => tokens.chart.parts,
      ExpenseCategory.other => tokens.chart.other,
    };
  }
}

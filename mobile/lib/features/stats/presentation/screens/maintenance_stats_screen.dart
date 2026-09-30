import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/stats/domain/maintenance_stats_calculator.dart';
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

/// Maintenance analytics: spend, top service type, most expensive job
/// (FRD stats.md).
class MaintenanceStatsScreen extends ConsumerStatefulWidget {
  const MaintenanceStatsScreen({super.key});

  @override
  ConsumerState<MaintenanceStatsScreen> createState() =>
      _MaintenanceStatsScreenState();
}

class _MaintenanceStatsScreenState
    extends ConsumerState<MaintenanceStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analyticsProvider)
          .track(AnalyticsEvent.statsOpened, {'screen': 'maintenance'});
    });
  }

  void _changePeriod(StatsPeriod period) {
    ref.read(maintenanceStatsPeriodProvider.notifier).state = period;
    ref.read(analyticsProvider).track(AnalyticsEvent.statsPeriodChanged, {
      'screen': 'maintenance',
      'year': period.year ?? 'all',
      'month': period.month ?? 'all',
    });
  }

  void _openDefinitions() {
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.statsDefinitionsOpened, {'screen': 'maintenance'});
    final s = AppLocalizations.of(context)!;
    showStatsDefinitions(
      context,
      title: s.maintenanceStatsTitle,
      entries: [
        s.statsDefPeriod,
        s.statsDefTotalJobs,
        s.statsDefTotalServiceItems,
        s.statsDefTotalCost,
        s.statsDefAvgJobCost,
        s.statsDefTopServiceType,
        s.statsDefMostExpensiveJob,
        s.statsDefUnits,
        s.statsDefMonthLabel,
        s.statsDefMonthlyCostChart,
        s.statsDefDonutService,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final stats = ref.watch(maintenanceStatsProvider);
    final period = ref.watch(maintenanceStatsPeriodProvider);
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
            title: s.serviceHistoryEmptyTitle,
            body: s.statsEmptyMaintenanceBody(vehicle.displayName),
            actionLabel: s.maintenanceRegisterService,
            actionKey: const Key('stats-empty-cta'),
            onAction: () => context.push(AppRoutes.maintenanceRegister),
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
            title: s.maintenanceStatsTitle,
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
                color: tokens.chart.maintenance,
                summary:
                    '${MoneyFormat.labeled(stats.totalCost, currency)} $currency',
                emptyLabel: s.statsChartNoData,
                selectedYear: period.year,
              ),
              StatsDonutChart(
                title: s.statsCostByServiceType,
                donut: stats.donut,
                labelOf: (key) =>
                    key == DonutChart.otherKey ? s.statsOther : key,
                valueOf: (slice) => MoneyFormat.labeled(slice.value, currency),
                summary:
                    '${MoneyFormat.labeled(stats.donut.total, currency)} $currency',
                emptyLabel: s.statsChartNoData,
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: Text(s.maintenanceStatsTitle)),
      body: body,
    );
  }

  List<StatsKpi> _kpis(
    MaintenanceStats stats,
    AppLocalizations s,
    String currency,
  ) {
    final avgSub = stats.avgJobCost != null
        ? MoneyFormat.labeled(stats.avgJobCost!, currency)
        : null;
    final topSub = stats.topServiceCost != null
        ? MoneyFormat.labeled(stats.topServiceCost!, currency)
        : null;
    final mostExpensive = stats.mostExpensiveCost != null
        ? MoneyFormat.labeled(stats.mostExpensiveCost!, currency)
        : null;
    final mostExpensiveSub = stats.mostExpensiveOn == null
        ? null
        : stats.mostExpensiveFirstItem == null
        ? DateFormat.yMMMd().format(stats.mostExpensiveOn!)
        : '${DateFormat.yMMMd().format(stats.mostExpensiveOn!)} · ${stats.mostExpensiveFirstItem}';

    return [
      StatsKpi(label: s.statsTotalJobs, value: '${stats.countInPeriod}'),
      StatsKpi(
        label: s.statsTotalServiceItems,
        value: '${stats.serviceItemCount}',
      ),
      StatsKpi(
        label: s.statsTotalCost,
        value: MoneyFormat.labeled(stats.totalCost, currency),
        sub: avgSub,
      ),
      StatsKpi(
        label: s.statsTopServiceType,
        value: stats.topServiceName,
        sub: topSub,
      ),
      StatsKpi(
        label: s.statsMostExpensiveJob,
        value: mostExpensive,
        sub: mostExpensiveSub,
      ),
    ];
  }
}

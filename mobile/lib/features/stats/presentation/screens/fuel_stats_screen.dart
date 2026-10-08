import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_access.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/stats/domain/fuel_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:dco_mobile/features/stats/presentation/stats_format.dart';
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

/// Adaptive fuel analytics: charge KPIs for electric vehicles, refuel KPIs
/// for petrol / hybrid-plugin (FRD stats.md).
class FuelStatsScreen extends ConsumerStatefulWidget {
  const FuelStatsScreen({super.key});

  @override
  ConsumerState<FuelStatsScreen> createState() => _FuelStatsScreenState();
}

class _FuelStatsScreenState extends ConsumerState<FuelStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analyticsProvider)
          .track(AnalyticsEvent.statsOpened, {'screen': 'fuel'});
    });
  }

  void _changePeriod(StatsPeriod period) {
    ref.read(fuelStatsPeriodProvider.notifier).state = period;
    ref.read(analyticsProvider).track(AnalyticsEvent.statsPeriodChanged, {
      'screen': 'fuel',
      'year': period.year ?? 'all',
      'month': period.month ?? 'all',
    });
  }

  void _openDefinitions(FuelStats stats) {
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.statsDefinitionsOpened, {'screen': 'fuel'});
    final s = AppLocalizations.of(context)!;
    final entries = [
      s.statsDefPeriod,
      s.statsDefFuelCount,
      s.statsDefTotalCost,
      if (stats.mode == FuelStatsMode.charge) ...[
        s.statsDefAvgCostPerKwh,
        s.statsDefTotalKwh,
      ] else ...[
        s.statsDefAvgCostPerUnit,
        s.statsDefTotalVolume,
      ],
      s.statsDefTotalDistance,
      if (stats.mode == FuelStatsMode.charge)
        s.statsDefAvgEfficiency
      else
        s.statsDefAvgConsumption,
      s.statsDefCostPer100,
      if (stats.mode == FuelStatsMode.charge)
        s.statsDefMostExpensiveCharge
      else
        s.statsDefMostExpensiveRefuel,
      s.statsDefSegments,
      s.statsDefUnits,
      s.statsDefMonthLabel,
      s.statsDefMonthlyCostChart,
      s.statsDefEfficiencyChart,
    ];
    showStatsDefinitions(context, title: s.fuelStatsTitle, entries: entries);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final access = VehicleAccess.of(vehicle, ref.watch(currentUserIdProvider));
    final stats = ref.watch(fuelStatsProvider);
    final period = ref.watch(fuelStatsPeriodProvider);
    final currency = ref.watch(currencyProvider).code;
    final lengthUnit = ref.watch(lengthUnitProvider);

    final body = vehicle == null
        ? DcoEmptyState(
            title: s.statsNoActiveVehicle,
            body: s.statsNoActiveVehicleBody,
          )
        : stats == null
        ? const StatsSkeleton()
        : !stats.hasAnyRecords
        ? DcoEmptyState(
            title: stats.mode == FuelStatsMode.charge
                ? s.fuelLogsEmptyTitleCharges
                : s.fuelLogsEmptyTitleRefuels,
            body: stats.mode == FuelStatsMode.charge
                ? s.statsEmptyFuelBodyCharges(vehicle.displayName)
                : s.statsEmptyFuelBodyRefuels(vehicle.displayName),
            actionLabel: !access.canCreate
                ? null
                : stats.mode == FuelStatsMode.charge
                ? FuelLogKind.charge.addLabel
                : FuelLogKind.refuel.addLabel,
            actionKey: const Key('stats-empty-cta'),
            onAction: access.canCreate
                ? () => context.push(AppRoutes.fuelLogNew)
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
            title: s.fuelStatsTitle,
            vehicleName: vehicle.displayName,
            period: period,
            yearOptions: stats.yearOptions,
            monthOptions: stats.monthOptions,
            onPeriodChanged: _changePeriod,
            onOpenDefinitions: () => _openDefinitions(stats),
            kpis: _kpis(stats, s, currency, lengthUnit),
            charts: [
              StatsBarChart(
                title: s.statsMonthlyCost,
                values: stats.monthlyCost,
                color: tokens.chart.fuel,
                summary:
                    '${MoneyFormat.labeled(stats.totalCost, currency)} $currency',
                emptyLabel: s.statsChartNoData,
                selectedYear: period.year,
              ),
              StatsLineChart(
                title: s.statsEfficiencyTrend,
                axisMonths: stats.monthlyCost,
                points: stats.monthlyEfficiency,
                color: tokens.chart.fuel,
                caption: statsEfficiencyUnit(stats.mode, lengthUnit),
                summary: stats.consumption != null
                    ? '${statsFixed2(stats.consumption!)} ${statsEfficiencyUnit(stats.mode, lengthUnit)}'
                    : statsDash,
                emptyLabel: s.statsChartNoData,
                selectedYear: period.year,
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: Text(s.fuelStatsTitle)),
      body: body,
    );
  }

  List<StatsKpi> _kpis(
    FuelStats stats,
    AppLocalizations s,
    String currency,
    MileageUnit lengthUnit,
  ) {
    final avgSub = stats.avgCostPerUnit != null && stats.singleUnit != null
        ? '${MoneyFormat.labeled(stats.avgCostPerUnit!, currency)}/${stats.singleUnit}'
        : null;
    final distance = stats.totalDeltaMiles != null
        ? MileageFormat.labeled(stats.totalDeltaMiles!, lengthUnit)
        : null;
    final per100 = stats.costPer100 != null
        ? '${MoneyFormat.labeled(stats.costPer100!, currency)}/100 ${lengthUnit.label}'
        : null;
    final mostExpensive = stats.mostExpensiveCost != null
        ? MoneyFormat.labeled(stats.mostExpensiveCost!, currency)
        : null;
    final mostExpensiveDate = stats.mostExpensiveOn != null
        ? DateFormat.yMMMd().format(stats.mostExpensiveOn!)
        : null;
    final volume = stats.volumeByUnit.isEmpty
        ? null
        : statsVolume(stats.volumeByUnit);

    if (stats.mode == FuelStatsMode.charge) {
      return [
        StatsKpi(label: s.statsTotalCharges, value: '${stats.countInPeriod}'),
        StatsKpi(
          label: s.statsTotalCost,
          value: MoneyFormat.labeled(stats.totalCost, currency),
          sub: avgSub,
        ),
        StatsKpi(label: s.statsTotalKwh, value: volume),
        StatsKpi(label: s.statsTotalDistance, value: distance),
        StatsKpi(
          label: s.statsAvgEfficiency,
          value: stats.consumption != null
              ? '${statsFixed2(stats.consumption!)} ${statsEfficiencyUnit(FuelStatsMode.charge, lengthUnit)}'
              : null,
        ),
        StatsKpi(label: s.statsCostPer100(lengthUnit.label), value: per100),
        StatsKpi(
          label: s.statsMostExpensiveCharge,
          value: mostExpensive,
          sub: mostExpensiveDate,
        ),
      ];
    }
    return [
      StatsKpi(label: s.statsTotalRefuels, value: '${stats.countInPeriod}'),
      StatsKpi(
        label: s.statsTotalCost,
        value: MoneyFormat.labeled(stats.totalCost, currency),
        sub: avgSub,
      ),
      StatsKpi(label: s.statsTotalVolume, value: volume),
      StatsKpi(label: s.statsTotalDistance, value: distance),
      StatsKpi(
        label: s.statsAvgConsumption,
        value: stats.consumption != null
            ? '${statsFixed2(stats.consumption!)} ${statsEfficiencyUnit(FuelStatsMode.refuel, lengthUnit)}'
            : null,
      ),
      StatsKpi(label: s.statsCostPer100(lengthUnit.label), value: per100),
      StatsKpi(
        label: s.statsMostExpensiveRefuel,
        value: mostExpensive,
        sub: mostExpensiveDate,
      ),
    ];
  }
}

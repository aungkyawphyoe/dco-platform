import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:dco_mobile/features/stats/presentation/widgets/stats_filter_bar.dart';
import 'package:dco_mobile/features/stats/presentation/widgets/stats_kpi_grid.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shared shell for the three stats screens: app bar, active-vehicle header
/// line, definitions action, filter row, KPI grid, then charts
/// (FRD stats.md common shell).
class StatsScaffold extends StatelessWidget {
  const StatsScaffold({
    super.key,
    required this.title,
    required this.vehicleName,
    required this.period,
    required this.yearOptions,
    required this.monthOptions,
    required this.onPeriodChanged,
    required this.onOpenDefinitions,
    required this.kpis,
    required this.charts,
  });

  final String title;
  final String vehicleName;
  final StatsPeriod period;
  final List<int> yearOptions;
  final List<int> monthOptions;
  final ValueChanged<StatsPeriod> onPeriodChanged;
  final VoidCallback onOpenDefinitions;
  final List<StatsKpi> kpis;
  final List<Widget> charts;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return ListView(
      padding: EdgeInsets.only(bottom: tokens.space.s6),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space.s4,
            tokens.space.s3,
            tokens.space.s4,
            tokens.space.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  vehicleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: tokens.text.secondary),
                ),
              ),
              TextButton.icon(
                key: const Key('stats-definitions'),
                onPressed: onOpenDefinitions,
                icon: Icon(Icons.info_outline, size: 18, color: tokens.text.link),
                label: Text(
                  s.statsDefinitionsAction,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: tokens.text.link),
                ),
              ),
            ],
          ),
        ),
        StatsFilterBar(
          period: period,
          yearOptions: yearOptions,
          monthOptions: monthOptions,
          onChanged: onPeriodChanged,
        ),
        StatsKpiGrid(kpis: kpis),
        for (var index = 0; index < charts.length; index++)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space.s4,
              index == 0 ? tokens.space.s3 : tokens.space.s3,
              tokens.space.s4,
              0,
            ),
            child: charts[index],
          ),
      ],
    );
  }
}

/// Static placeholder shown while local records hydrate (FRD stats.md
/// error states — no spinner deadlock).
class StatsSkeleton extends StatelessWidget {
  const StatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget box({double height = 16, double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: tokens.background.skeleton,
            borderRadius: BorderRadius.circular(tokens.radius.md),
          ),
        );

    Widget card(double height) => Container(
          height: height,
          decoration: BoxDecoration(
            color: tokens.background.skeleton,
            borderRadius: BorderRadius.circular(tokens.radius.lg),
          ),
        );

    return Padding(
      padding: EdgeInsets.all(tokens.space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(width: 140),
          SizedBox(height: tokens.space.s4),
          Row(
            children: [
              Expanded(child: card(56)),
              SizedBox(width: tokens.space.s3),
              Expanded(child: card(56)),
            ],
          ),
          SizedBox(height: tokens.space.s4),
          Row(
            children: [
              Expanded(child: card(96)),
              SizedBox(width: tokens.space.s3),
              Expanded(child: card(96)),
            ],
          ),
          SizedBox(height: tokens.space.s3),
          card(200),
          SizedBox(height: tokens.space.s3),
          card(200),
        ],
      ),
    );
  }
}

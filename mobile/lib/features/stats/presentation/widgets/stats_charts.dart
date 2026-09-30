import 'dart:math' as math;

import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/stats/domain/stats_models.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

TextStyle _axisStyle(BuildContext context) {
  final tokens = context.tokens;
  return GoogleFonts.ibmPlexMono(
    color: tokens.text.caption,
    fontSize: 10,
  );
}

BoxDecoration _cardDecoration(DcoTokens tokens) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        tokens.background.card,
        tokens.background.card.withValues(alpha: 0.7),
      ],
    ),
    borderRadius: BorderRadius.circular(tokens.radius.lg),
    boxShadow: tokens.shadows.card,
  );
}

/// Title row shared by all stats charts.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.summary,
    this.caption,
    required this.child,
  });

  final String title;
  final String summary;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      label: '$title. $summary',
      child: Container(
        padding: EdgeInsets.all(tokens.space.s4),
        decoration: _cardDecoration(tokens),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (caption != null) ...[
              SizedBox(height: 2),
              Text(
                caption!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: tokens.text.caption),
              ),
            ],
            SizedBox(height: tokens.space.s3),
            child,
          ],
        ),
      ),
    );
  }
}

/// Monthly cost bar chart: one bar per month in the period (FRD stats.md).
class StatsBarChart extends StatelessWidget {
  const StatsBarChart({
    super.key,
    required this.title,
    required this.values,
    required this.color,
    required this.summary,
    required this.emptyLabel,
    this.selectedYear,
  });

  final String title;
  final List<MonthValue> values;
  final Color color;
  final String summary;
  final String emptyLabel;
  final int? selectedYear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final body = SizedBox(
      height: 180,
      child: values.isEmpty
          ? Center(
              child: Text(
                emptyLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: tokens.text.caption),
              ),
            )
          : BarChart(_barData(context)),
    );
    return _ChartCard(
      title: title,
      summary: summary,
      child: body,
    );
  }

  BarChartData _barData(BuildContext context) {
    final tokens = context.tokens;
    final maxValue =
        values.fold<double>(0, (max, item) => item.value > max ? item.value : max);
    final interval = maxValue <= 0 ? null : _niceInterval(maxValue);
    return BarChartData(
      maxY: maxValue > 0 ? maxValue * 1.15 : 1,
      barTouchData: const BarTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: tokens.border.subtle,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: interval,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                NumberFormat.compact().format(value),
                style: _axisStyle(context),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= values.length) {
                return const SizedBox.shrink();
              }
              final step = (values.length / 6).ceil();
              if (values.length > 7 && index % step != 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  statsMonthLabel(
                    values[index].date,
                    selectedYear: selectedYear,
                  ),
                  style: _axisStyle(context),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var index = 0; index < values.length; index++)
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index].value,
                color: color,
                width: 14,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
      ],
    );
  }

  static double _niceInterval(double maxValue) {
    final raw = maxValue / 3;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floorToDouble()).toDouble();
    final normalized = raw / magnitude;
    final step = normalized <= 1
        ? 1.0
        : normalized <= 2
        ? 2.0
        : normalized <= 5
        ? 5.0
        : 10.0;
    return step * magnitude;
  }
}

/// Efficiency trend line chart. [points] is sparse — months without a
/// valid segment render as gaps, never interpolated (FRD stats.md).
class StatsLineChart extends StatelessWidget {
  const StatsLineChart({
    super.key,
    required this.title,
    required this.axisMonths,
    required this.points,
    required this.color,
    required this.summary,
    required this.emptyLabel,
    this.caption,
    this.selectedYear,
  });

  final String title;
  final List<MonthValue> axisMonths;
  final List<MonthValue> points;
  final Color color;
  final String summary;
  final String emptyLabel;
  final String? caption;
  final int? selectedYear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final body = SizedBox(
      height: 180,
      child: axisMonths.isEmpty || points.isEmpty
          ? Center(
              child: Text(
                emptyLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: tokens.text.caption),
              ),
            )
          : LineChart(_lineData(context)),
    );
    return _ChartCard(
      title: title,
      caption: caption,
      summary: summary,
      child: body,
    );
  }

  LineChartData _lineData(BuildContext context) {
    final tokens = context.tokens;
    final pointIndex = <int, double>{
      for (final point in points)
        if (axisMonths.indexWhere(
              (month) => month.year == point.year && month.month == point.month,
            ) >=
            0)
          axisMonths.indexWhere(
            (month) => month.year == point.year && month.month == point.month,
          ): point.value,
    };
    final spots = <List<FlSpot>>[];
    List<FlSpot>? run;
    for (var index = 0; index < axisMonths.length; index++) {
      final value = pointIndex[index];
      if (value == null) {
        run = null;
        continue;
      }
      final spot = FlSpot(index.toDouble(), value);
      if (run == null) {
        run = [spot];
        spots.add(run);
      } else {
        run.add(spot);
      }
    }

    final maxValue =
        points.fold<double>(0, (max, item) => item.value > max ? item.value : max);
    final minValue = points.fold<double>(
      maxValue,
      (min, item) => item.value < min ? item.value : min,
    );
    final pad = ((maxValue - minValue) * 0.2) + maxValue * 0.05 + 1;

    return LineChartData(
      minY: math.max(0, minValue - pad),
      maxY: maxValue + pad,
      lineTouchData: const LineTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: tokens.border.subtle,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value.toStringAsFixed(1),
                style: _axisStyle(context),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= axisMonths.length) {
                return const SizedBox.shrink();
              }
              final step = (axisMonths.length / 6).ceil();
              if (axisMonths.length > 7 && index % step != 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  statsMonthLabel(
                    axisMonths[index].date,
                    selectedYear: selectedYear,
                  ),
                  style: _axisStyle(context),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        for (final run in spots)
          LineChartBarData(
            spots: run,
            isCurved: false,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: run.length <= 12),
            belowBarData: BarAreaData(show: false),
          ),
      ],
    );
  }
}

/// Donut chart for grouped costs (service type / expense category).
class StatsDonutChart extends StatelessWidget {
  const StatsDonutChart({
    super.key,
    required this.title,
    required this.donut,
    required this.labelOf,
    required this.valueOf,
    this.colorOf,
    required this.summary,
    required this.emptyLabel,
  });

  final String title;
  final DonutChart donut;

  /// Raw key → display label (`$other` → "Other").
  final String Function(String key) labelOf;

  /// Slice → formatted value (money etc).
  final String Function(DonutSlice slice) valueOf;

  /// Optional palette override; default cycles the Garage chart colors, with
  /// the collapsed "Other" slice always in `tokens.chart.other`.
  final Color Function(int index, String key)? colorOf;

  final String summary;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final palette = [
      tokens.chart.fuel,
      tokens.chart.maintenance,
      tokens.chart.insurance,
      tokens.chart.parking,
      tokens.chart.tolls,
      tokens.chart.parts,
    ];
    Color colorFor(int index, String key) {
      if (key == DonutChart.otherKey) return tokens.chart.other;
      if (colorOf != null) return colorOf!(index, key);
      return palette[index % palette.length];
    }

    final body = donut.isEmpty
        ? SizedBox(
            height: 140,
            child: Center(
              child: Text(
                emptyLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: tokens.text.caption),
              ),
            ),
          )
        : Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      for (var index = 0; index < donut.slices.length; index++)
                        PieChartSectionData(
                          value: donut.slices[index].value,
                          color: colorFor(index, donut.slices[index].key),
                          radius: 34,
                          title: '',
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: tokens.space.s4),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < donut.slices.length; index++)
                      Padding(
                        padding: EdgeInsets.only(bottom: tokens.space.s2),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colorFor(index, donut.slices[index].key),
                                borderRadius:
                                    BorderRadius.circular(tokens.radius.full),
                              ),
                            ),
                            SizedBox(width: tokens.space.s2),
                            Expanded(
                              child: Text(
                                labelOf(donut.slices[index].key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            SizedBox(width: tokens.space.s2),
                            Text(
                              valueOf(donut.slices[index]),
                              style: GoogleFonts.ibmPlexMono(
                                color: tokens.text.secondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

    return _ChartCard(
      title: title,
      summary: summary,
      child: body,
    );
  }
}


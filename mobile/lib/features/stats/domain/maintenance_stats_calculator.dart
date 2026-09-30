import '../../maintenance/domain/entities/service_record.dart';
import 'stats_models.dart';
import 'stats_period.dart';

/// KPI set for Maintenance Stats, computed over service records + their line
/// items (FRD stats.md).
class MaintenanceStats {
  const MaintenanceStats({
    required this.totalRecords,
    required this.countInPeriod,
    required this.serviceItemCount,
    required this.totalCost,
    required this.topServiceName,
    required this.topServiceCost,
    required this.mostExpensiveCost,
    required this.mostExpensiveOn,
    required this.mostExpensiveFirstItem,
    required this.monthlyCost,
    required this.donut,
    required this.yearOptions,
    required this.monthOptions,
  });

  final int totalRecords;
  final int countInPeriod;
  final int serviceItemCount;
  final double totalCost;

  /// Line-item name with the highest summed `line_cost` (> 0); ties → most
  /// recent occurrence.
  final String? topServiceName;
  final double? topServiceCost;

  final double? mostExpensiveCost;
  final DateTime? mostExpensiveOn;

  /// First line item's name on the most expensive job, when present.
  final String? mostExpensiveFirstItem;

  final List<MonthValue> monthlyCost;

  /// Σ `line_cost` grouped by item name → top four + Other when > 5.
  final DonutChart donut;

  final List<int> yearOptions;
  final List<int> monthOptions;

  bool get hasAnyRecords => totalRecords > 0;
  bool get hasRecordsInPeriod => countInPeriod > 0;

  double? get avgJobCost =>
      countInPeriod > 0 ? totalCost / countInPeriod : null;

  static MaintenanceStats compute({
    required List<ServiceRecord> records,
    required StatsPeriod period,
  }) {
    final dates = records.map((record) => record.servicedOn);
    final yearOptions = statsYearOptions(dates);
    final monthOptions = statsMonthOptions(dates, year: period.year);

    final inPeriod =
        records.where((record) => period.matches(record.servicedOn)).toList();

    var totalCost = 0.0;
    var serviceItemCount = 0;
    final costByName = <String, double>{};
    final lastByName = <String, DateTime>{};
    ServiceRecord? mostExpensive;

    for (final record in inPeriod) {
      totalCost += record.totalCost;
      serviceItemCount += record.items.length;
      for (final item in record.items) {
        final cost = item.lineCost ?? 0;
        if (cost > 0) {
          costByName[item.name] = (costByName[item.name] ?? 0) + cost;
        }
        final seen = lastByName[item.name];
        if (seen == null || record.servicedOn.isAfter(seen)) {
          lastByName[item.name] = record.servicedOn;
        }
      }
      if (mostExpensive == null ||
          record.totalCost > mostExpensive.totalCost ||
          (record.totalCost == mostExpensive.totalCost &&
              record.servicedOn.isAfter(mostExpensive.servicedOn))) {
        mostExpensive = record;
      }
    }

    String? topName;
    double topCost = 0;
    costByName.forEach((name, cost) {
      if (cost < topCost) return;
      if (cost > topCost) {
        topName = name;
        topCost = cost;
        return;
      }
      final best = topName;
      if (best != null && lastByName[name]!.isAfter(lastByName[best]!)) {
        topName = name;
      }
    });

    final monthlyCost = MonthAccumulator();
    for (final record in inPeriod) {
      monthlyCost.add(record.servicedOn, record.totalCost);
    }

    return MaintenanceStats(
      totalRecords: records.length,
      countInPeriod: inPeriod.length,
      serviceItemCount: serviceItemCount,
      totalCost: totalCost,
      topServiceName: topCost > 0 ? topName : null,
      topServiceCost: topCost > 0 ? topCost : null,
      mostExpensiveCost: mostExpensive?.totalCost,
      mostExpensiveOn: mostExpensive?.servicedOn,
      mostExpensiveFirstItem: mostExpensive?.items.isEmpty ?? true
          ? null
          : mostExpensive!.items.first.name,
      monthlyCost: monthlyCost.values,
      donut: DonutChart.fromTotals(costByName),
      yearOptions: yearOptions,
      monthOptions: monthOptions,
    );
  }
}

import '../../../core/units/mileage_unit.dart';
import '../../fuel/domain/entities/fuel_log.dart';
import 'stats_models.dart';
import 'stats_period.dart';

/// KPI set for the adaptive Fuel Stats screen. Electric vehicles get charge
/// KPIs, petrol / hybrid-plugin get refuel KPIs (FRD stats.md).
enum FuelStatsMode { refuel, charge }

/// Two consecutive odometer readings, both inside the filtered period.
/// Amount and cost are the later reading's values (fuel added since the
/// previous reading — the accepted partial-fill approximation).
class FuelSegment {
  const FuelSegment({
    required this.on,
    required this.deltaMiles,
    required this.amount,
    required this.cost,
    required this.unit,
  });

  /// The later reading's date; also the efficiency-trend month bucket.
  final DateTime on;

  /// Distance between the readings, canonical storage (miles).
  final double deltaMiles;
  final double amount;
  final double cost;
  final String unit;
}

class FuelStats {
  const FuelStats({
    required this.mode,
    required this.totalRecords,
    required this.countInPeriod,
    required this.totalCost,
    required this.volumeByUnit,
    required this.segments,
    required this.totalDeltaMiles,
    required this.consumption,
    required this.costPer100,
    required this.mostExpensiveCost,
    required this.mostExpensiveOn,
    required this.monthlyCost,
    required this.monthlyEfficiency,
    required this.yearOptions,
    required this.monthOptions,
    required this.lengthUnit,
  });

  final FuelStatsMode mode;

  /// All records for the vehicle (drives the "no records yet" empty state).
  final int totalRecords;
  final int countInPeriod;
  final double totalCost;

  /// In-period volume grouped by the log's snapshotted unit (e.g. L, gal).
  final Map<String, double> volumeByUnit;

  /// Valid in-period segments in chronological order.
  final List<FuelSegment> segments;

  /// Sum of segment deltas, canonical storage (miles); null under 2 segments.
  final double? totalDeltaMiles;

  /// Refuel: L/100 km (km) or mpg (mi). Charge: km/kWh or mi/kWh.
  /// Null under 2 segments or when segment units are mixed.
  final double? consumption;

  /// Money per 100 display-distance units; null under 2 segments.
  final double? costPer100;

  final double? mostExpensiveCost;
  final DateTime? mostExpensiveOn;

  final List<MonthValue> monthlyCost;

  /// Sparse — only months containing at least one valid segment.
  final List<MonthValue> monthlyEfficiency;

  final List<int> yearOptions;
  final List<int> monthOptions;
  final MileageUnit lengthUnit;

  bool get hasAnyRecords => totalRecords > 0;
  bool get hasRecordsInPeriod => countInPeriod > 0;
  bool get hasSegments => segments.length >= 2;

  /// Non-null only when every in-period log shares one volume unit.
  String? get singleUnit =>
      volumeByUnit.length == 1 ? volumeByUnit.keys.first : null;

  /// Total cost ÷ total volume; needs a single unit and volume > 0.
  double? get avgCostPerUnit {
    final unit = singleUnit;
    if (unit == null) return null;
    final volume = volumeByUnit[unit] ?? 0;
    if (volume <= 0) return null;
    return totalCost / volume;
  }

  static const _litersPerGallon = 3.785411784;

  /// Outlier bound in display units (FRD stats.md): 10,000 km / 6,000 mi.
  static double outlierBoundMiles(MileageUnit unit) =>
      unit.toStorage(unit == MileageUnit.km ? 10000.0 : 6000.0);

  static FuelStats compute({
    required List<FuelLog> logs,
    required StatsPeriod period,
    required MileageUnit lengthUnit,
    required FuelStatsMode mode,
  }) {
    final dates = logs.map((log) => log.loggedOn);
    final yearOptions = statsYearOptions(dates);
    final monthOptions = statsMonthOptions(dates, year: period.year);

    final inPeriod =
        logs.where((log) => period.matches(log.loggedOn)).toList();
    var totalCost = 0.0;
    final volumeByUnit = <String, double>{};
    FuelLog? mostExpensive;
    for (final log in inPeriod) {
      totalCost += log.cost;
      volumeByUnit[log.unit] = (volumeByUnit[log.unit] ?? 0) + log.amount;
      if (mostExpensive == null ||
          log.cost > mostExpensive.cost ||
          (log.cost == mostExpensive.cost &&
              log.loggedOn.isAfter(mostExpensive.loggedOn))) {
        mostExpensive = log;
      }
    }

    final segments = _segments(logs, period: period, lengthUnit: lengthUnit);

    final deltaMiles =
        segments.fold<double>(0, (sum, segment) => sum + segment.deltaMiles);
    final segmentCosts =
        segments.fold<double>(0, (sum, segment) => sum + segment.cost);
    final hasSegments = segments.length >= 2;
    final distanceDisplay = lengthUnit.toDisplay(deltaMiles);

    double? consumption;
    double? costPer100;
    if (hasSegments && distanceDisplay > 0) {
      costPer100 = segmentCosts / distanceDisplay * 100;
      consumption = _consumption(
        segments: segments,
        distanceDisplay: distanceDisplay,
        mode: mode,
        lengthUnit: lengthUnit,
      );
    }

    final monthlyCost = MonthAccumulator();
    for (final log in inPeriod) {
      monthlyCost.add(log.loggedOn, log.cost);
    }

    return FuelStats(
      mode: mode,
      totalRecords: logs.length,
      countInPeriod: inPeriod.length,
      totalCost: totalCost,
      volumeByUnit: volumeByUnit,
      segments: segments,
      totalDeltaMiles: hasSegments ? deltaMiles : null,
      consumption: consumption,
      costPer100: costPer100,
      mostExpensiveCost: mostExpensive?.cost,
      mostExpensiveOn: mostExpensive?.loggedOn,
      monthlyCost: monthlyCost.values,
      monthlyEfficiency: _monthlyEfficiency(
        segments,
        lengthUnit: lengthUnit,
        mode: mode,
      ),
      yearOptions: yearOptions,
      monthOptions: monthOptions,
      lengthUnit: lengthUnit,
    );
  }

  /// Pairs consecutive odometer readings across the vehicle's full history;
  /// both endpoints must sit inside the period, later ≥ earlier, and the
  /// delta must clear the outlier bound. Invalid pairs are skipped
  /// individually and do not break neighboring pairs.
  static List<FuelSegment> _segments(
    List<FuelLog> logs, {
    required StatsPeriod period,
    required MileageUnit lengthUnit,
  }) {
    final sorted = [...logs]
      ..sort((a, b) {
        final byDate = a.loggedOn.compareTo(b.loggedOn);
        if (byDate != 0) return byDate;
        final byCreated = a.createdAt.compareTo(b.createdAt);
        if (byCreated != 0) return byCreated;
        return a.id.compareTo(b.id);
      });
    final readings =
        sorted.where((log) => log.odometer != null).toList(growable: false);
    final bound = outlierBoundMiles(lengthUnit);
    final segments = <FuelSegment>[];
    for (var i = 1; i < readings.length; i++) {
      final earlier = readings[i - 1];
      final later = readings[i];
      if (!period.matches(earlier.loggedOn) || !period.matches(later.loggedOn)) {
        continue;
      }
      final delta = later.odometer! - earlier.odometer!;
      if (delta < 0 || delta > bound) continue;
      segments.add(
        FuelSegment(
          on: later.loggedOn,
          deltaMiles: delta,
          amount: later.amount,
          cost: later.cost,
          unit: later.unit,
        ),
      );
    }
    return segments;
  }

  static double? _consumption({
    required List<FuelSegment> segments,
    required double distanceDisplay,
    required FuelStatsMode mode,
    required MileageUnit lengthUnit,
  }) {
    final units = segments.map((segment) => segment.unit).toSet();
    if (units.length != 1 || distanceDisplay <= 0) return null;
    final volume =
        segments.fold<double>(0, (sum, segment) => sum + segment.amount);
    if (volume <= 0) return null;
    if (mode == FuelStatsMode.charge) {
      return distanceDisplay / volume;
    }
    final unit = units.first;
    if (lengthUnit == MileageUnit.km) {
      final liters =
          unit == 'L' ? volume : volume * _litersPerGallon; // gal → L
      return liters / distanceDisplay * 100;
    }
    final gallons =
        unit == 'gal' ? volume : volume / _litersPerGallon; // L → gal
    return distanceDisplay / gallons;
  }

  /// One point per month containing ≥ 1 segment; months without one stay
  /// gaps. Mixed segment units or zero totals skip the month's point.
  static List<MonthValue> _monthlyEfficiency(
    List<FuelSegment> segments, {
    required MileageUnit lengthUnit,
    required FuelStatsMode mode,
  }) {
    final grouped = <DateTime, List<FuelSegment>>{};
    for (final segment in segments) {
      grouped
          .putIfAbsent(
            DateTime(segment.on.year, segment.on.month),
            () => <FuelSegment>[],
          )
          .add(segment);
    }
    final points = <MonthValue>[];
    for (final entry in grouped.entries) {
      final group = entry.value;
      final units = group.map((segment) => segment.unit).toSet();
      if (units.length != 1) continue;
      final deltaDisplay =
          lengthUnit.toDisplay(group.fold(0.0, (s, g) => s + g.deltaMiles));
      final volume = group.fold<double>(0, (s, g) => s + g.amount);
      if (deltaDisplay <= 0 || volume <= 0) continue;
      final value = mode == FuelStatsMode.charge
          ? deltaDisplay / volume
          : _consumption(
              segments: group,
              distanceDisplay: deltaDisplay,
              mode: mode,
              lengthUnit: lengthUnit,
            );
      if (value == null) continue;
      points.add(MonthValue(entry.key.year, entry.key.month, value));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }
}

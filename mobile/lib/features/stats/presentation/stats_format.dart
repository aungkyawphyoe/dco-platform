import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/stats/domain/fuel_stats_calculator.dart';

/// Rendered where a KPI is gated off (FRD stats.md).
const String statsDash = '—';

/// Whole when integral, otherwise two decimals (log-amount style).
String statsNumber(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

/// Two decimals — the FRD rule for derived KPIs.
String statsFixed2(double value) => value.toStringAsFixed(2);

/// Unit shown with consumption / efficiency KPI values.
///
/// Refuel: `l/100 km` (km) or `mpg` (mi). Charge: `km/kWh` or `mi/kWh`.
String statsEfficiencyUnit(FuelStatsMode mode, MileageUnit lengthUnit) {
  if (mode == FuelStatsMode.charge) {
    return lengthUnit == MileageUnit.km ? 'km/kWh' : 'mi/kWh';
  }
  return lengthUnit == MileageUnit.km ? 'l/100 km' : 'mpg';
}

/// Per-unit volume lines joined for mixed-unit periods (`120 L\n40 gal`).
String statsVolume(Map<String, double> volumeByUnit) {
  final lines = [
    for (final entry in volumeByUnit.entries) '${statsNumber(entry.value)} ${entry.key}',
  ];
  return lines.join('\n');
}

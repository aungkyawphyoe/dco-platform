import 'package:dco_mobile/features/expenses/providers.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/stats/domain/expense_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/fuel_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/maintenance_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-screen filter state. autoDispose so each screen opens on All / All
/// (FRD stats.md) and period state never leaks between screens.
final fuelStatsPeriodProvider =
    StateProvider.autoDispose<StatsPeriod>((_) => StatsPeriod.all);
final maintenanceStatsPeriodProvider =
    StateProvider.autoDispose<StatsPeriod>((_) => StatsPeriod.all);
final expenseStatsPeriodProvider =
    StateProvider.autoDispose<StatsPeriod>((_) => StatsPeriod.all);

/// null while the active vehicle or its records are still hydrating.
final fuelStatsProvider = Provider.autoDispose<FuelStats?>((ref) {
  final kind = ref.watch(vehicleFuelLogKindProvider);
  final logs = ref.watch(vehicleFuelLogsProvider).valueOrNull;
  if (kind == null || logs == null) return null;
  return FuelStats.compute(
    logs: logs,
    period: ref.watch(fuelStatsPeriodProvider),
    lengthUnit: ref.watch(lengthUnitProvider),
    mode: kind == FuelLogKind.charge ? FuelStatsMode.charge : FuelStatsMode.refuel,
  );
});

final maintenanceStatsProvider = Provider.autoDispose<MaintenanceStats?>((
  ref,
) {
  final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
  final records = ref.watch(maintenanceHistoryProvider).valueOrNull;
  if (vehicle == null || records == null) return null;
  return MaintenanceStats.compute(
    records: records,
    period: ref.watch(maintenanceStatsPeriodProvider),
  );
});

final expenseStatsProvider = Provider.autoDispose<ExpenseStats?>((ref) {
  final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
  final expenses = ref.watch(vehicleExpensesProvider).valueOrNull;
  if (vehicle == null || expenses == null) return null;
  return ExpenseStats.compute(
    expenses: expenses,
    period: ref.watch(expenseStatsPeriodProvider),
  );
});

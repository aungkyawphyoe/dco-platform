import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(const []);
  return ref.watch(expenseRepositoryProvider).watchForVehicle(vehicleId);
});

final vehicleExpenseSummaryProvider = StreamProvider<ExpenseSummary>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(ExpenseSummary.empty);
  return ref.watch(expenseRepositoryProvider).watchSummary(vehicleId);
});

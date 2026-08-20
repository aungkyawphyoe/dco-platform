import '../entities/expense.dart';

abstract class ExpenseRepository {
  Stream<List<Expense>> watchForVehicle(String vehicleId);

  Stream<ExpenseSummary> watchSummary(String vehicleId, {DateTime? now});

  Future<Expense?> getById(String id);

  Future<Expense> add({
    required String userId,
    required String vehicleId,
    required ExpenseDraft draft,
  });

  Future<Expense> update({
    required String userId,
    required String expenseId,
    required ExpenseDraft draft,
  });

  Future<void> delete({
    required String userId,
    required String expenseId,
  });
}

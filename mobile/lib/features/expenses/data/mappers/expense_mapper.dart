import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/expense.dart';

Expense expenseFromDrift(ExpenseRecord row, [List<ExpensePartRecord> parts = const []]) {
  return Expense(
    id: row.id,
    vehicleId: row.vehicleId,
    category: ExpenseCategory.parse(row.category),
    amount: row.amount,
    incurredOn: row.incurredOn,
    notes: row.notes,
    receiptLocalPath: row.receiptLocalPath,
    receiptMediaId: row.receiptMediaId,
    parts: parts.map(expenseAssignedPartFromDrift).toList(),
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

ExpenseAssignedPart expenseAssignedPartFromDrift(ExpensePartRecord row) {
  return ExpenseAssignedPart(
    id: row.id,
    partId: row.partId,
    name: row.name,
  );
}

ExpenseRecordsCompanion expenseToCompanion(Expense expense) {
  return ExpenseRecordsCompanion.insert(
    id: expense.id,
    vehicleId: expense.vehicleId,
    category: expense.category.storage,
    amount: expense.amount,
    incurredOn: expense.incurredOn,
    notes: Value(expense.notes),
    receiptLocalPath: Value(expense.receiptLocalPath),
    receiptMediaId: Value(expense.receiptMediaId),
    updatedAt: expense.updatedAt,
    createdAt: expense.createdAt,
  );
}

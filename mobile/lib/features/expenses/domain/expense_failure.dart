sealed class ExpenseFailure implements Exception {
  const ExpenseFailure(this.message);
  final String message;
}

class ExpenseValidationFailure extends ExpenseFailure {
  const ExpenseValidationFailure(super.message);
}

class ExpenseNotFoundFailure extends ExpenseFailure {
  const ExpenseNotFoundFailure([super.message = 'Expense not found']);
}

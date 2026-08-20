import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/domain/expense_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amount must be greater than zero and at most 999,999.99', () {
    expect(ExpenseValidators.amount(''), 'Amount is required');
    expect(ExpenseValidators.amount('0'), 'Enter an amount greater than 0');
    expect(ExpenseValidators.amount('-1'), 'Enter an amount greater than 0');
    expect(ExpenseValidators.amount('1000000'), 'Amount must be 999,999.99 or less');
    expect(ExpenseValidators.amount('12.5'), isNull);
    expect(ExpenseValidators.amount('999999.99'), isNull);
  });

  test('date allows today plus one day and rejects the day after', () {
    final now = DateTime(2026, 8, 20);
    expect(ExpenseValidators.date(null, now: now), 'Date is required');
    expect(ExpenseValidators.date(DateTime(2026, 8, 20), now: now), isNull);
    expect(ExpenseValidators.date(DateTime(2026, 8, 21), now: now), isNull);
    expect(
      ExpenseValidators.date(DateTime(2026, 8, 22), now: now),
      'Date cannot be more than one day in the future',
    );
  });

  test('notes are optional up to 500 characters', () {
    expect(ExpenseValidators.notes(null), isNull);
    expect(ExpenseValidators.notes(''), isNull);
    expect(ExpenseValidators.notes('a' * 500), isNull);
    expect(ExpenseValidators.notes('a' * 501), 'Notes must be 500 characters or fewer');
  });

  test('category is required', () {
    expect(ExpenseValidators.category(null), 'Category is required');
    expect(ExpenseValidators.category(ExpenseCategory.fuel), isNull);
  });
}

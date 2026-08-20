import 'entities/expense.dart';

abstract final class ExpenseValidators {
  static const maxAmount = 999999.99;
  static const maxNotesLength = 500;

  static String? category(ExpenseCategory? value) {
    if (value == null) return 'Category is required';
    return null;
  }

  static String? amount(String value) {
    final parsed = parseDecimal(value);
    if (parsed == null) return 'Amount is required';
    if (parsed <= 0) return 'Enter an amount greater than 0';
    if (parsed > maxAmount) return 'Amount must be 999,999.99 or less';
    return null;
  }

  static String? date(DateTime? value, {required DateTime now}) {
    if (value == null) return 'Date is required';
    final picked = DateTime(value.year, value.month, value.day);
    final latest = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    if (picked.isAfter(latest)) return 'Date cannot be more than one day in the future';
    return null;
  }

  static String? notes(String? value) {
    if (value == null) return null;
    if (value.trim().length > maxNotesLength) {
      return 'Notes must be $maxNotesLength characters or fewer';
    }
    return null;
  }

  static double? parseDecimal(String value) {
    final trimmed = value.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  static double money(double value) => (value * 100).roundToDouble() / 100;
}

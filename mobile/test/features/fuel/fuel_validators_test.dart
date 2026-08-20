import 'package:dco_mobile/features/fuel/domain/fuel_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amount must be greater than zero', () {
    expect(FuelLogValidators.amount(''), 'Amount is required');
    expect(FuelLogValidators.amount('0'), 'Enter an amount greater than 0');
    expect(FuelLogValidators.amount('12.5'), isNull);
  });

  test('cost may be zero but not negative', () {
    expect(FuelLogValidators.cost(''), 'Cost is required');
    expect(FuelLogValidators.cost('-1'), 'Enter a valid cost');
    expect(FuelLogValidators.cost('0'), isNull);
    expect(FuelLogValidators.cost('8.40'), isNull);
  });

  test('date cannot be in the future', () {
    final now = DateTime(2026, 8, 20);
    expect(FuelLogValidators.date(null, now: now), 'Date is required');
    expect(FuelLogValidators.date(DateTime(2026, 8, 21), now: now), 'Date cannot be in the future');
    expect(FuelLogValidators.date(DateTime(2026, 8, 20), now: now), isNull);
  });
}

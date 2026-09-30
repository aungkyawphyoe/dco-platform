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

  test('odometer is optional but validated when present', () {
    expect(FuelLogValidators.odometer(''), isNull);
    expect(FuelLogValidators.odometer('  '), isNull);
    expect(FuelLogValidators.odometer('12345'), isNull);
    expect(FuelLogValidators.odometer('12,345'), isNull);
    expect(FuelLogValidators.odometer('abc'), 'Enter a valid odometer');
    expect(FuelLogValidators.odometer('-1'), 'Odometer cannot be negative');
    expect(
      FuelLogValidators.odometer('1000000'),
      'Odometer is too large',
    );
  });

  test('odometer rejects values below the vehicle mileage', () {
    expect(
      FuelLogValidators.odometer('99', vehicleMileage: 100),
      'Odometer cannot be below vehicle mileage',
    );
    expect(FuelLogValidators.odometer('100', vehicleMileage: 100), isNull);
    expect(FuelLogValidators.odometer('101', vehicleMileage: 100), isNull);
    // Mileage does not apply to blank input.
    expect(FuelLogValidators.odometer('', vehicleMileage: 100), isNull);
  });

  test('parseOdometer returns null for blank input', () {
    expect(FuelLogValidators.parseOdometer(''), isNull);
    expect(FuelLogValidators.parseOdometer(' '), isNull);
    expect(FuelLogValidators.parseOdometer('42.5'), 42.5);
  });
}

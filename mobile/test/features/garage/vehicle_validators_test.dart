import 'package:dco_mobile/features/garage/domain/vehicle_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('year bounds', () {
    expect(VehicleValidators.year('1899', now: DateTime(2026)), isNotNull);
    expect(VehicleValidators.year('2026', now: DateTime(2026)), isNull);
    expect(VehicleValidators.year('2028', now: DateTime(2026)), isNotNull);
  });

  test('plate max 20', () {
    expect(VehicleValidators.licensePlate('ABC123'), isNull);
    expect(VehicleValidators.licensePlate('A' * 21), isNotNull);
  });

  test('VIN is optional unless supplied', () {
    expect(VehicleValidators.vin(''), isNull);
    expect(VehicleValidators.vin('SHORT'), isNotNull);
    expect(VehicleValidators.vin('1HGBH41JXMN109186'), isNull);
  });
}

import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MileageUnit', () {
    test('kilometers convert from stored miles and back', () {
      const storedMiles = 10000.0;
      final displayed = MileageUnit.km.toDisplay(storedMiles);
      expect(displayed, closeTo(16093.44, 0.001));
      expect(
        MileageUnit.km.toStorage(displayed),
        closeTo(storedMiles, 0.000001),
      );
    });

    test('parse returns km', () {
      expect(MileageUnit.parse('km'), MileageUnit.km);
      expect(MileageUnit.parse('mi'), MileageUnit.km);
      expect(MileageUnit.parse('yards'), MileageUnit.km);
    });
  });

  group('MileageFormat', () {
    test('labels stored miles in the selected unit', () {
      expect(MileageFormat.labeled(10000, MileageUnit.km), '16,093 km');
    });

    test('input rounds kilometers to a whole number', () {
      expect(MileageFormat.input(10000, MileageUnit.km), '16093');
      expect(
        MileageFormat.input(MileageUnit.km.toStorage(5000.6), MileageUnit.km),
        '5001',
      );
      expect(MileageFormat.input(0, MileageUnit.km), '0');
    });
    test('unchanged rounded reading retains fractional storage', () {
      final original = MileageUnit.km.toStorage(5000.4);
      expect(
        MileageFormat.fromInput(5000, MileageUnit.km, original: original),
        original,
      );
      expect(
        MileageUnit.km.toDisplay(
          MileageFormat.fromInput(5001, MileageUnit.km, original: original),
        ),
        closeTo(5001, 0.000001),
      );
      expect(
        MileageUnit.km.toDisplay(MileageFormat.fromInput(5000, MileageUnit.km)),
        closeTo(5000, 0.000001),
      );
    });
  });
}

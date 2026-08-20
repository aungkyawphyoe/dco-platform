import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MileageUnit', () {
    test('miles display and storage are identity', () {
      expect(MileageUnit.mi.toDisplay(10000), 10000);
      expect(MileageUnit.mi.toStorage(10000), 10000);
    });

    test('kilometers convert from stored miles and back', () {
      const storedMiles = 10000.0;
      final displayed = MileageUnit.km.toDisplay(storedMiles);
      expect(displayed, closeTo(16093.44, 0.001));
      expect(MileageUnit.km.toStorage(displayed), closeTo(storedMiles, 0.000001));
    });

    test('parse treats unknown values as miles', () {
      expect(MileageUnit.parse('km'), MileageUnit.km);
      expect(MileageUnit.parse('mi'), MileageUnit.mi);
      expect(MileageUnit.parse('yards'), MileageUnit.mi);
    });
  });

  group('MileageFormat', () {
    test('labels stored miles in the selected unit', () {
      expect(MileageFormat.labeled(10000, MileageUnit.mi), '10,000 mi');
      expect(MileageFormat.labeled(10000, MileageUnit.km), '16,093 km');
    });

    test('input hydrates a whole mile value and a one-decimal km value', () {
      expect(MileageFormat.input(10000, MileageUnit.mi), '10000');
      expect(MileageFormat.input(10000, MileageUnit.km), '16093.4');
    });
  });
}

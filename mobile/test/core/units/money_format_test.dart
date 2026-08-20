import 'package:dco_mobile/core/units/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('USD', () {
    test('always shows two decimal places', () {
      expect(MoneyFormat.labeled(12, 'USD'), '12.00 USD');
      expect(MoneyFormat.labeled(12.5, 'USD'), '12.50 USD');
      expect(MoneyFormat.labeled(12.56, 'USD'), '12.56 USD');
    });

    test('uses thousands separators and does not compact', () {
      expect(MoneyFormat.labeled(23000, 'USD'), '23,000.00 USD');
      expect(MoneyFormat.labeled(23000000, 'USD'), '23,000,000.00 USD');
    });

    test('form input keeps cents', () {
      expect(MoneyFormat.input(12.5, 'USD'), '12.50');
      expect(MoneyFormat.input(12, 'USD'), '12.00');
    });
  });

  group('MMK', () {
    test('hides fraction digits', () {
      expect(MoneyFormat.labeled(500, 'MMK'), '500 MMK');
      expect(MoneyFormat.labeled(500.4, 'MMK'), '500 MMK');
      expect(MoneyFormat.labeled(500.6, 'MMK'), '501 MMK');
    });

    test('uses K and M suffixes for large amounts', () {
      expect(MoneyFormat.labeled(23000, 'MMK'), '23K MMK');
      expect(MoneyFormat.labeled(25000, 'MMK'), '25K MMK');
      expect(MoneyFormat.labeled(23500, 'MMK'), '23.5K MMK');
      expect(MoneyFormat.labeled(23000000, 'MMK'), '23M MMK');
      expect(MoneyFormat.labeled(1550000, 'MMK'), '1.6M MMK');
    });

    test('does not compact values under one thousand', () {
      expect(MoneyFormat.labeled(999, 'MMK'), '999 MMK');
      expect(MoneyFormat.labeled(1000, 'MMK'), '1K MMK');
    });

    test('form input is a whole number, never compact', () {
      expect(MoneyFormat.input(23000, 'MMK'), '23000');
      expect(MoneyFormat.input(12.4, 'MMK'), '12');
    });
  });
}

import 'package:dco_mobile/features/dashboard/domain/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GreetingCalculator.forDateTime', () {
    test('morning covers 00:00 through 11:59', () {
      expect(
        GreetingCalculator.forDateTime(DateTime(2026, 1, 1, 0)),
        Greeting.morning,
      );
      expect(
        GreetingCalculator.forDateTime(DateTime(2026, 1, 1, 5)),
        Greeting.morning,
      );
      expect(
        GreetingCalculator.forDateTime(DateTime(2026, 1, 1, 11, 59)),
        Greeting.morning,
      );
    });

    test('afternoon covers 12:00 through 16:59', () {
      expect(
        GreetingCalculator.forDateTime(DateTime(2026, 1, 1, 12)),
        Greeting.afternoon,
      );
      expect(
        GreetingCalculator.forDateTime(DateTime(2026, 1, 1, 16, 59)),
        Greeting.afternoon,
      );
    });

    test('evening covers 17:00 through 23:59', () {
      expect(
        GreetingCalculator.forDateTime(DateTime(2026, 1, 1, 17)),
        Greeting.evening,
      );
      expect(
        GreetingCalculator.forDateTime(DateTime(2026, 1, 1, 23, 59)),
        Greeting.evening,
      );
    });
  });
}

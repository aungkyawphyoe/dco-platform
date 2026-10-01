enum Greeting { morning, afternoon, evening }

class GreetingCalculator {
  const GreetingCalculator._();

  static Greeting forDateTime(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return Greeting.morning;
    if (hour < 17) return Greeting.afternoon;
    return Greeting.evening;
  }
}

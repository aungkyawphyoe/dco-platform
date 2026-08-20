import 'package:intl/intl.dart';

import 'mileage_unit.dart';

/// Formats stored (miles) distances in the owner's selected length unit.
abstract final class MileageFormat {
  static final _whole = NumberFormat('#,###');

  static String number(double storedMiles, MileageUnit unit) {
    return _whole.format(unit.toDisplay(storedMiles).round());
  }

  static String labeled(double storedMiles, MileageUnit unit) {
    return '${number(storedMiles, unit)} ${unit.label}';
  }

  static String input(double storedMiles, MileageUnit unit) {
    final displayed = unit.toDisplay(storedMiles);
    if (unit == MileageUnit.mi) {
      return displayed.truncateToDouble() == displayed
          ? displayed.toStringAsFixed(0)
          : displayed.toString();
    }
    return displayed.toStringAsFixed(1);
  }
}

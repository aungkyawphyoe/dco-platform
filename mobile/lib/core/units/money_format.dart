import 'package:intl/intl.dart';

/// Display rules for logged amounts. Storage stays a decimal; this is view-only.
///
/// USD: always two fraction digits, with thousands separators.
/// MMK: whole kyat, no decimals. Values ≥ 1,000 use K / M suffixes.
abstract final class MoneyFormat {
  static final _usd = NumberFormat('#,##0.00');
  static final _whole = NumberFormat('#,###');

  static bool isMmk(String currencyCode) => currencyCode.toUpperCase() == 'MMK';

  static String labeled(double amount, String currencyCode) {
    return '${number(amount, currencyCode)} ${currencyCode.toUpperCase()}';
  }

  static String number(double amount, String currencyCode) {
    if (isMmk(currencyCode)) return _mmk(amount);
    return _usd.format(amount);
  }

  /// Full digits for form fields. Never compact; MMK has no fraction digits.
  static String input(double amount, String currencyCode) {
    if (isMmk(currencyCode)) return amount.round().toString();
    return amount.toStringAsFixed(2);
  }

  static String _mmk(double amount) {
    final sign = amount < 0 ? '-' : '';
    final whole = amount.abs().round();
    if (whole >= 1000000) {
      return '$sign${_compact(whole / 1000000)}M';
    }
    if (whole >= 1000) {
      final thousands = whole / 1000;
      if (thousands >= 1000) return '$sign${_compact(thousands / 1000)}M';
      return '$sign${_compact(thousands)}K';
    }
    return '$sign${_whole.format(whole)}';
  }

  static String _compact(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) return rounded.round().toString();
    return rounded.toStringAsFixed(1);
  }
}

import '../../../../core/units/mileage_unit.dart';

enum AppLanguage {
  english,
  myanmar;

  String get code => switch (this) {
    AppLanguage.english => 'en',
    AppLanguage.myanmar => 'my',
  };

  String get label => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.myanmar => 'Myanmar',
  };

  static AppLanguage parse(String value) {
    return value == 'my' || value == AppLanguage.myanmar.name
        ? AppLanguage.myanmar
        : AppLanguage.english;
  }
}

enum AppCurrency {
  usd,
  mmk;

  String get code => switch (this) {
    AppCurrency.usd => 'USD',
    AppCurrency.mmk => 'MMK',
  };

  String get label => switch (this) {
    AppCurrency.usd => 'US Dollar (USD)',
    AppCurrency.mmk => 'Myanmar Kyat (MMK)',
  };

  static AppCurrency parse(String value) {
    final normalized = value.toUpperCase();
    return normalized == 'MMK' || value == AppCurrency.mmk.name
        ? AppCurrency.mmk
        : AppCurrency.usd;
  }
}

class UserPreferences {
  const UserPreferences({
    required this.language,
    required this.currency,
    required this.lengthUnit,
  });

  static const defaults = UserPreferences(
    language: AppLanguage.english,
    currency: AppCurrency.usd,
    lengthUnit: MileageUnit.mi,
  );

  final AppLanguage language;
  final AppCurrency currency;
  final MileageUnit lengthUnit;

  UserPreferences copyWith({
    AppLanguage? language,
    AppCurrency? currency,
    MileageUnit? lengthUnit,
  }) {
    return UserPreferences(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      lengthUnit: lengthUnit ?? this.lengthUnit,
    );
  }
}

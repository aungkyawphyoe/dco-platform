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

enum AppThemeMode {
  system,
  light,
  dark;

  String get code => switch (this) {
    AppThemeMode.system => 'system',
    AppThemeMode.light => 'light',
    AppThemeMode.dark => 'dark',
  };

  String get label => switch (this) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };

  static AppThemeMode parse(String value) {
    // Enum names are the same strings ('light'/'dark'/'system').
    return switch (value) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }
}

class UserPreferences {
  const UserPreferences({
    required this.language,
    required this.currency,
    required this.lengthUnit,
    this.themeMode = AppThemeMode.system,
    this.soonDays = 30,
    this.soonDistanceKm = 500,
  });

  static const defaults = UserPreferences(
    language: AppLanguage.myanmar,
    currency: AppCurrency.mmk,
    lengthUnit: MileageUnit.km,
    themeMode: AppThemeMode.system,
    soonDays: 30,
    soonDistanceKm: 500,
  );

  final AppLanguage language;
  final AppCurrency currency;
  final MileageUnit lengthUnit;

  /// Light / Dark / follow the system. Default: system.
  final AppThemeMode themeMode;

  /// How many days before the due date a plan item counts as upcoming.
  final int soonDays;

  /// Remaining distance (km) at which a plan item counts as upcoming.
  final double soonDistanceKm;

  UserPreferences copyWith({
    AppLanguage? language,
    AppCurrency? currency,
    MileageUnit? lengthUnit,
    AppThemeMode? themeMode,
    int? soonDays,
    double? soonDistanceKm,
  }) {
    return UserPreferences(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      lengthUnit: lengthUnit ?? this.lengthUnit,
      themeMode: themeMode ?? this.themeMode,
      soonDays: soonDays ?? this.soonDays,
      soonDistanceKm: soonDistanceKm ?? this.soonDistanceKm,
    );
  }
}

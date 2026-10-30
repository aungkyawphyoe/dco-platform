import '../../core/currency/currency_store.dart';
import '../../core/storage/entry_preferences.dart';
import 'dart:ui';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/settings/data/datasources/email_reminder_settings_api.dart';
import 'package:dco_mobile/features/settings/domain/entities/email_reminder_settings.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userPreferencesProvider = StreamProvider<UserPreferences>((ref) {
  final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
  if (userId == null) return Stream.value(UserPreferences.defaults);
  return ref.watch(preferencesRepositoryProvider).watch(userId);
});

final localeProvider = Provider<Locale>((ref) {
  final entry =
      ref.watch(entryPreferencesProvider).valueOrNull?.language ?? 'en';
  final signedIn = ref.watch(sessionControllerProvider).valueOrNull != null;
  return Locale(
    signedIn
        ? (ref.watch(userPreferencesProvider).valueOrNull?.language.code ??
              entry)
        : entry,
  );
});

final lengthUnitProvider = Provider<MileageUnit>((ref) {
  return ref.watch(userPreferencesProvider).valueOrNull?.lengthUnit ??
      MileageUnit.km;
});

/// The account/fleet selection, independent of the legacy display preference.
/// recordDatabaseProvider selects the isolated organization database for drivers.
final selectedCurrencyStateProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  return CurrencyStore(ref.watch(recordDatabaseProvider)).watch(userId);
});

final currencyProvider = Provider<AppCurrency>((ref) {
  return ref.watch(userPreferencesProvider).valueOrNull?.currency ??
      AppCurrency.mmk;
});

/// Light / Dark / System choice from Settings → Appearance (default: system).
///
/// The signed-in account's saved choice wins. Before a session exists (and
/// right after logout) the device-wide entry choice is used so splash,
/// introduction, login and signup match the theme the user last picked.
final themeModeProvider = Provider<AppThemeMode>((ref) {
  final signedIn = ref.watch(sessionControllerProvider).valueOrNull != null;
  final accountMode = signedIn
      ? ref.watch(userPreferencesProvider).valueOrNull?.themeMode
      : null;
  if (accountMode != null) return accountMode;

  final entryMode =
      ref.watch(entryPreferencesProvider).valueOrNull?.themeMode ??
      ref.watch(initialEntryThemeProvider);
  return entryMode == null
      ? AppThemeMode.system
      : AppThemeMode.parse(entryMode);
});

/// Clamped reminder thresholds (soon days / soon distance) from user prefs.
final reminderThresholdsProvider = Provider<DueThresholds>((ref) {
  final prefs =
      ref.watch(userPreferencesProvider).valueOrNull ??
      UserPreferences.defaults;
  return DueThresholds.fromValues(
    soonDays: prefs.soonDays,
    soonDistanceKm: prefs.soonDistanceKm,
  );
});

final emailReminderSettingsApiProvider = Provider<EmailReminderSettingsApi>((
  ref,
) {
  if (ref.watch(appConfigProvider).mockAuth) {
    return MockEmailReminderSettingsApi();
  }
  return DioEmailReminderSettingsApi(ref.watch(dioProvider));
});

final emailReminderSettingsProvider =
    FutureProvider.autoDispose<EmailReminderSettings>((ref) {
      return ref.watch(emailReminderSettingsApiProvider).get();
    });

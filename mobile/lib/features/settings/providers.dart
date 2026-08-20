import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userPreferencesProvider = StreamProvider<UserPreferences>((ref) {
  final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
  if (userId == null) return Stream.value(UserPreferences.defaults);
  return ref.watch(preferencesRepositoryProvider).watch(userId);
});

final lengthUnitProvider = Provider<MileageUnit>((ref) {
  return ref.watch(userPreferencesProvider).valueOrNull?.lengthUnit ?? MileageUnit.mi;
});

final currencyProvider = Provider<AppCurrency>((ref) {
  return ref.watch(userPreferencesProvider).valueOrNull?.currency ?? AppCurrency.usd;
});

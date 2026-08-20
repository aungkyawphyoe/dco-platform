import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/units/mileage_unit.dart';
import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/preferences_repository.dart';

class PreferencesRepositoryImpl implements PreferencesRepository {
  PreferencesRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<UserPreferences> watch(String userId) {
    final query = _db.select(_db.userProfiles)..where((row) => row.userId.equals(userId));
    return query.watch().map((rows) {
      if (rows.isEmpty) return UserPreferences.defaults;
      return _fromRow(rows.first);
    });
  }

  @override
  Future<UserPreferences> get(String userId) async {
    final row = await (_db.select(
      _db.userProfiles,
    )..where((r) => r.userId.equals(userId))).getSingleOrNull();
    if (row == null) return UserPreferences.defaults;
    return _fromRow(row);
  }

  @override
  Future<void> save({
    required String userId,
    required UserPreferences preferences,
  }) async {
    final existing = await (_db.select(
      _db.userProfiles,
    )..where((r) => r.userId.equals(userId))).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              userId: userId,
              language: Value(preferences.language.code),
              currency: Value(preferences.currency.code),
              lengthUnit: Value(preferences.lengthUnit.name),
            ),
          );
      return;
    }
    await (_db.update(_db.userProfiles)..where((row) => row.userId.equals(userId))).write(
      UserProfilesCompanion(
        language: Value(preferences.language.code),
        currency: Value(preferences.currency.code),
        lengthUnit: Value(preferences.lengthUnit.name),
      ),
    );
  }

  UserPreferences _fromRow(UserProfile row) {
    return UserPreferences(
      language: AppLanguage.parse(row.language),
      currency: AppCurrency.parse(row.currency),
      lengthUnit: MileageUnit.parse(row.lengthUnit),
    );
  }
}

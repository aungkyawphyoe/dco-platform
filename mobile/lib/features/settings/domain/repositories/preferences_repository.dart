import '../entities/user_preferences.dart';

abstract class PreferencesRepository {
  Stream<UserPreferences> watch(String userId);

  Future<UserPreferences> get(String userId);

  Future<void> save({required String userId, required UserPreferences preferences});
}

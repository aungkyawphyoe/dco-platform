import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/storage/entry_preferences.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedOutSession extends SessionController {
  @override
  Future<Session?> build() async => null;
}

class _SignedInSession extends SessionController {
  @override
  Future<Session?> build() async => Session(
    accessToken: 'test',
    refreshToken: 'test',
    user: User(
      id: 'user-1',
      email: 'owner@example.com',
      username: 'owner',
      role: 'owner',
      plan: 'free',
      status: 'active',
      emailVerified: true,
      mustChangePassword: false,
    ),
  );
}

void main() {
  test(
    'signed-out theme follows the device entry choice after logout',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sessionControllerProvider.overrideWith(_SignedOutSession.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(entryPreferencesProvider.future);
      await container.read(sessionControllerProvider.future);
      expect(container.read(themeModeProvider), AppThemeMode.system);

      // Settings → Appearance writes the device choice; it must survive logout.
      await container
          .read(entryPreferencesProvider.notifier)
          .themeMode('light');
      expect(container.read(themeModeProvider), AppThemeMode.light);

      await container.read(entryPreferencesProvider.notifier).themeMode('dark');
      expect(container.read(themeModeProvider), AppThemeMode.dark);
    },
  );

  test(
    'signed-in theme prefers the account choice over the device choice',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sessionControllerProvider.overrideWith(_SignedInSession.new),
          userPreferencesProvider.overrideWith(
            (ref) => Stream.value(
              UserPreferences.defaults.copyWith(themeMode: AppThemeMode.light),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(entryPreferencesProvider.future);
      await container.read(entryPreferencesProvider.notifier).themeMode('dark');
      await container.read(sessionControllerProvider.future);
      await container.read(userPreferencesProvider.future);

      expect(container.read(themeModeProvider), AppThemeMode.light);
    },
  );
}

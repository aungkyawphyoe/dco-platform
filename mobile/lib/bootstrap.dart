import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'core/notifications/flutter_local_notification_client.dart';
import 'core/providers.dart';
import 'core/storage/secure_token_store.dart';

Future<List<Override>> bootstrap() async {
  final config = AppConfig.fromEnvironment();
  final tokenStore = SecureTokenStore();
  final database = AppDatabase();
  final notifications = FlutterLocalNotificationClient();
  await notifications.initialize();
  return [
    appConfigProvider.overrideWithValue(config),
    tokenStoreProvider.overrideWithValue(tokenStore),
    appDatabaseProvider.overrideWithValue(database),
    localNotificationClientProvider.overrideWithValue(notifications),
  ];
}

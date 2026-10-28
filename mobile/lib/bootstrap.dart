import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/analytics/analytics.dart';
import 'core/analytics/firebase_analytics_sink.dart';
import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'core/notifications/flutter_local_notification_client.dart';
import 'core/providers.dart';
import 'core/storage/entry_preferences.dart';
import 'core/storage/secure_token_store.dart';

Future<List<Override>> bootstrap() async {
  final config = AppConfig.fromEnvironment();
  final tokenStore = SecureTokenStore();
  final database = AppDatabase();
  final notifications = FlutterLocalNotificationClient();
  await notifications.initialize();
  final analytics = await _initAnalytics(config);
  return [
    appConfigProvider.overrideWithValue(config),
    tokenStoreProvider.overrideWithValue(tokenStore),
    appDatabaseProvider.overrideWithValue(database),
    localNotificationClientProvider.overrideWithValue(notifications),
    analyticsProvider.overrideWithValue(analytics),
    initialEntryThemeProvider.overrideWithValue(
      await _readEntryTheme(database),
    ),
  ];
}

/// Reads the device-wide appearance choice before `runApp` so the splash
/// honors Light / Dark instead of briefly defaulting to System.
Future<String?> _readEntryTheme(AppDatabase database) async {
  try {
    final row = await (database.select(
      database.appMeta,
    )..where((r) => r.key.equals('entry.theme'))).getSingleOrNull();
    return row?.value;
  } catch (_) {
    return null;
  }
}

/// Best-effort Firebase init. When the native config files are absent (a
/// fresh checkout or a build without `flutterfire configure`) the app must
/// still start — analytics just no-ops.
Future<Analytics> _initAnalytics(AppConfig config) async {
  if (!config.analyticsEnabled) return const Analytics();
  try {
    await Firebase.initializeApp();
    return Analytics(FirebaseAnalyticsSink(FirebaseAnalytics.instance));
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        '[analytics] Firebase is not configured; analytics disabled. '
        'Run `flutterfire configure` and add google-services.json / '
        'GoogleService-Info.plist. Cause: $error',
      );
    }
    return const Analytics();
  }
}

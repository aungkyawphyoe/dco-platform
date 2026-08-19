import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/dio_auth_remote_datasource.dart';
import '../../features/auth/data/datasources/mock_auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/garage/data/repositories/vehicle_repository_impl.dart';
import '../../features/garage/domain/repositories/vehicle_repository.dart';
import 'analytics/analytics.dart';
import 'config/app_config.dart';
import 'database/app_database.dart';
import 'network/dio_client.dart';
import 'storage/token_store.dart';
import 'sync/outbox_writer.dart';
import 'sync/sync_engine.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig must be overridden in bootstrap');
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  throw StateError('TokenStore must be overridden in bootstrap');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('AppDatabase must be overridden in bootstrap');
});

final analyticsProvider = Provider<Analytics>((ref) => const Analytics());

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokens = ref.watch(tokenStoreProvider);
  final client = DioClient(
    config: config,
    tokenStore: tokens,
    refreshTokens: () async {
      final refresh = await tokens.readRefreshToken();
      if (refresh == null) return null;
      final bare = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      try {
        final response = await bare.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refresh_token': refresh},
        );
        final session = Session.fromJson(response.data!);
        await tokens.writeSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userJson: jsonEncode(session.user.toJson()),
        );
        return (
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
      } on DioException {
        return null;
      }
    },
  );
  return client.dio;
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.mockAuth) {
    return MockAuthRemoteDataSource();
  }
  return DioAuthRemoteDataSource(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final outboxWriterProvider = Provider<OutboxWriter>((ref) {
  return OutboxWriter(ref.watch(appDatabaseProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) => const SyncEngine());

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    outbox: ref.watch(outboxWriterProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

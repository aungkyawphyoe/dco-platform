import 'dart:async';
import 'package:dco_mobile/core/storage/memory_token_store.dart';
import 'package:dco_mobile/features/auth/data/datasources/mock_auth_remote_datasource.dart';
import 'package:dco_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dco_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dco_mobile/features/auth/domain/auth_failure.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingRefresh extends MockAuthRemoteDataSource {
  FailingRefresh(this.failure);
  final AuthFailure failure;

  @override
  Future<Session> refresh({required String refreshToken}) async =>
      throw failure;
}

class DelayedRefresh extends MockAuthRemoteDataSource {
  final entered = Completer<void>();
  final response = Completer<Session>();
  @override
  Future<Session> refresh({required String refreshToken}) {
    entered.complete();
    return response.future;
  }
}

void main() {
  test('temporary HTTP failures map to retryable auth failures', () {
    expect(mapStatusToAuthFailure(429, 'Wait'), isA<RateLimitedFailure>());
    expect(
      mapStatusToAuthFailure(503, 'Wait'),
      isA<ServiceUnavailableFailure>(),
    );
  });
  late MemoryTokenStore tokens;
  setUp(() async {
    tokens = MemoryTokenStore();
    await tokens.writeSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      userJson: '{}',
    );
  });

  test(
    'a rate-limited restore preserves credentials and surfaces retry failure',
    () async {
      final repository = AuthRepositoryImpl(
        remote: FailingRefresh(const RateLimitedFailure()),
        tokenStore: tokens,
      );
      await expectLater(
        repository.restoreSession(),
        throwsA(isA<RateLimitedFailure>()),
      );
      expect(await tokens.readAccessToken(), 'access');
      expect(await tokens.readRefreshToken(), 'refresh');
    },
  );

  test('a service outage preserves credentials', () async {
    final repository = AuthRepositoryImpl(
      remote: FailingRefresh(const ServiceUnavailableFailure()),
      tokenStore: tokens,
    );
    await expectLater(
      repository.restoreSession(),
      throwsA(isA<ServiceUnavailableFailure>()),
    );
    expect(await tokens.readRefreshToken(), 'refresh');
  });

  test('an invalid refresh still clears credentials', () async {
    final repository = AuthRepositoryImpl(
      remote: FailingRefresh(const InvalidCredentialsFailure()),
      tokenStore: tokens,
    );
    expect(await repository.restoreSession(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });
  for (final fails in [false, true]) {
    test(
      'late refresh fails=$fails cannot overwrite or clear a newer account',
      () async {
        final remote = DelayedRefresh();
        final repository = AuthRepositoryImpl(
          remote: remote,
          tokenStore: tokens,
        );
        final restore = repository.restoreSession();
        await remote.entered.future;
        await tokens.clear();
        await tokens.writeSession(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          userJson: '{"id":"new"}',
        );
        if (fails) {
          remote.response.completeError(const InvalidCredentialsFailure());
          expect(await restore, isNull);
        } else {
          remote.response.complete(
            Session.fromJson({
              'access_token': 'old-access',
              'refresh_token': 'old-refresh',
              'user': {
                'id': 'old',
                'email': 'old@test.local',
                'username': 'old',
                'role': 'owner',
                'plan': 'free',
                'status': 'active',
                'email_verified': true,
                'must_change_password': false,
              },
            }),
          );
          await expectLater(restore, throwsStateError);
        }
        expect(await tokens.readRefreshToken(), 'new-refresh');
        expect(await tokens.readUserJson(), '{"id":"new"}');
      },
    );
  }
}

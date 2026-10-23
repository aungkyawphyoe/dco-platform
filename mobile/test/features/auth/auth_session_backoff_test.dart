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
  Future<Session> refresh({required String refreshToken}) async => throw failure;
}

void main() {
  test('temporary HTTP failures map to retryable auth failures', () {
    expect(mapStatusToAuthFailure(429, 'Wait'), isA<RateLimitedFailure>());
    expect(mapStatusToAuthFailure(503, 'Wait'), isA<ServiceUnavailableFailure>());
  });
  late MemoryTokenStore tokens;
  setUp(() async {
    tokens = MemoryTokenStore();
    await tokens.writeSession(
      accessToken: 'access', refreshToken: 'refresh', userJson: '{}',
    );
  });

  test('a rate-limited restore preserves credentials and surfaces retry failure', () async {
    final repository = AuthRepositoryImpl(
      remote: FailingRefresh(const RateLimitedFailure()), tokenStore: tokens,
    );
    await expectLater(repository.restoreSession(), throwsA(isA<RateLimitedFailure>()));
    expect(await tokens.readAccessToken(), 'access');
    expect(await tokens.readRefreshToken(), 'refresh');
  });

  test('a service outage preserves credentials', () async {
    final repository = AuthRepositoryImpl(
      remote: FailingRefresh(const ServiceUnavailableFailure()), tokenStore: tokens,
    );
    await expectLater(repository.restoreSession(), throwsA(isA<ServiceUnavailableFailure>()));
    expect(await tokens.readRefreshToken(), 'refresh');
  });

  test('an invalid refresh still clears credentials', () async {
    final repository = AuthRepositoryImpl(
      remote: FailingRefresh(const InvalidCredentialsFailure()), tokenStore: tokens,
    );
    expect(await repository.restoreSession(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/providers.dart';
import '../domain/auth_failure.dart';
import '../domain/entities/session.dart';

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).signIn(
        email: email,
        password: password,
      );
      ref.read(analyticsProvider).track(AnalyticsEvent.authSignedIn);
      return session;
    });
    _throwIfError();
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      ref.read(analyticsProvider).track(AnalyticsEvent.authSignedUp);
      return session;
    });
    _throwIfError();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.read(analyticsProvider).track(AnalyticsEvent.authSignedOut);
    state = const AsyncData(null);
  }

  Future<void> requestPasswordReset({required String email}) async {
    await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
    ref.read(analyticsProvider).track(AnalyticsEvent.authPasswordResetRequested);
  }

  Future<void> resendVerification() {
    return ref.read(authRepositoryProvider).resendVerification();
  }

  void _throwIfError() {
    final error = state.error;
    if (error != null) {
      throw error is AuthFailure ? error : UnknownAuthFailure(error.toString());
    }
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, Session?>(
  SessionController.new,
);

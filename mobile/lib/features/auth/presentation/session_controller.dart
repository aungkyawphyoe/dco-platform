import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/providers.dart';
import '../../family/providers.dart';
import '../domain/auth_failure.dart';
import '../domain/entities/session.dart';

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> signIn({required String email, required String password, String? surface}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).signIn(
        email: email,
        password: password,
        surface: surface,
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
    try {
      await ref.read(familyRepositoryProvider).clearFamilyCache();
    } catch (_) {}
    state = const AsyncData(null);
  }

  Future<void> requestPasswordReset({required String email}) async {
    await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
    ref.read(analyticsProvider).track(AnalyticsEvent.authPasswordResetRequested);
  }

  Future<void> resendVerification() {
    return ref.read(authRepositoryProvider).resendVerification();
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await ref.read(authRepositoryProvider).changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    // After successful password change, the user's must_change_password flag is cleared server-side.
    // We need to refresh the session to get the updated user.
    final session = await ref.read(authRepositoryProvider).restoreSession();
    if (session != null) {
      state = AsyncData(session);
    }
  }

  void updateUser(User user) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWithUser(user));
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

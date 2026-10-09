import '../account_security_providers.dart';
import 'dart:convert';
import '../../../core/storage/entry_preferences.dart';
import '../../../core/router/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/providers.dart';
import '../../vehicle_sharing/providers.dart';
import '../domain/auth_failure.dart';
import '../domain/entities/session.dart';

class SessionController extends AsyncNotifier<Session?> {
  bool _changingAccount = false;
  Future<T> _withAccountChange<T>(Future<T> Function() change) async {
    if (_changingAccount) {
      throw const UnknownAuthFailure('Sign-in is already in progress');
    }
    _changingAccount = true;
    final engine = ref.read(syncEngineProvider);
    try {
      await engine.pauseForAccountChange();
      return await change();
    } finally {
      _changingAccount = false;
      engine.resumeAfterAccountChange();
    }
  }

  @override
  Future<Session?> build() async {
    final session = await ref.read(authRepositoryProvider).restoreSession();
    if (session != null) {
      await ref.read(entryPreferencesProvider.notifier).complete();
    }
    return session;
  }

  Future<void> signIn({
    required String email,
    required String password,
    String? surface,
  }) async {
    await _withAccountChange(() async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final session = await ref
            .read(authRepositoryProvider)
            .signIn(email: email, password: password, surface: surface);
        await _prepare(session, false);
        ref.read(analyticsProvider).track(AnalyticsEvent.authSignedIn);
        return session;
      });
      _throwIfError();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _withAccountChange(() async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final session = await ref
            .read(authRepositoryProvider)
            .signUp(email: email, password: password, displayName: displayName);
        await _prepare(session, true);
        ref.read(analyticsProvider).track(AnalyticsEvent.authSignedUp);
        return session;
      });
      _throwIfError();
    });
  }

  Future<void> _prepare(Session session, bool isNew) async {
    await ref
        .read(entryPreferencesProvider.notifier)
        .initializeAccountLanguage(session.user.id);
    await ref.read(entryPreferencesProvider.notifier).complete();
    ref.read(newOwnerSetupProvider.notifier).state = isNew;
    ref
        .read(postAuthRouteProvider.notifier)
        .state = ref.read(pendingSocialLinkProvider) != null
        ? AppRoutes.accountConnections
        : (!session.user.emailVerified && session.user.email.isNotEmpty)
        ? AppRoutes.verifyEmail
        : (ref.read(pendingCollaborationProvider) ??
              (isNew ? AppRoutes.firstVehicle : null));
  }

  Future<void> acceptSocialSession(Map<String, dynamic> response) async {
    await _withAccountChange(() async {
      final session = Session.fromJson(response);
      await ref
          .read(tokenStoreProvider)
          .writeSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userJson: jsonEncode(session.user.toJson()),
          );
      await _prepare(session, response['is_new'] == true);
      state = AsyncData(session);
    });
  }

  Future<void> refreshAccount() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final data = await ref.read(accountSecurityProvider).profile();
    final user = User.fromJson(
      data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : data,
    );
    if (state.valueOrNull?.user.id != current.user.id) return;
    final store = ref.read(tokenStoreProvider);
    final session = Session(
      accessToken: await store.readAccessToken() ?? current.accessToken,
      refreshToken: await store.readRefreshToken() ?? current.refreshToken,
      user: user,
    );
    await ref
        .read(tokenStoreProvider)
        .writeSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userJson: jsonEncode(user.toJson()),
        );
    state = AsyncData(session);
  }

  Future<void> signOut() async {
    await _withAccountChange(() async {
      await ref.read(authRepositoryProvider).signOut();
      ref.read(analyticsProvider).track(AnalyticsEvent.authSignedOut);
      try {
        await ref.read(vehicleShareRepositoryProvider).clearCache();
      } catch (_) {}
      ref.read(postAuthRouteProvider.notifier).state = null;
      ref.read(newOwnerSetupProvider.notifier).state = false;
      ref.read(pendingSocialLinkProvider.notifier).state = null;
      ref.read(pendingCollaborationProvider.notifier).state = null;
      state = const AsyncData(null);
    });
  }

  Future<void> requestPasswordReset({required String email}) async {
    await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.authPasswordResetRequested);
  }

  Future<void> resendVerification() {
    return ref.read(authRepositoryProvider).resendVerification();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .changePassword(
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

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

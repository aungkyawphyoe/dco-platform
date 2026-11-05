import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import 'package:flutter/painting.dart';
import '../../../core/storage/account_lifecycle.dart';
import '../account_security_providers.dart';
import 'dart:convert';
import '../../../core/storage/entry_preferences.dart';
import '../../../core/router/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/providers.dart';
import '../domain/auth_failure.dart';
import '../domain/entities/session.dart';

class SessionController extends AsyncNotifier<Session?> {
  bool _changingAccount = false;
  bool _restoring = true;

  Future<void> _awaitRestore() async {
    if (!_restoring) return;
    try {
      await future;
    } catch (_) {
      /* Reauthentication can recover a failed restore. */
    }
  }

  Future<T> _withAccountChange<T>(Future<T> Function() change) async {
    if (_changingAccount) {
      throw const UnknownAuthFailure('Sign-in is already in progress');
    }
    _changingAccount = true;
    ref.read(accountTransitionProvider.notifier).state = true;
    final coordinator = ref.read(syncAccountCoordinatorProvider);
    var resumeSync = true;
    try {
      await coordinator.pause();
      return await change();
    } on LogoutSyncFailure {
      resumeSync = false;
      rethrow;
    } finally {
      _changingAccount = false;
      ref.read(accountTransitionProvider.notifier).state = false;
      coordinator.resume(sync: resumeSync);
    }
  }

  @override
  Future<Session?> build() async {
    try {
      final lifecycle = ref.read(accountLifecycleProvider);
      try {
        await lifecycle.initialize();
      } finally {
        _publishLifecycle();
      }
      final cached = await ref.read(tokenStoreProvider).readUserJson();
      Session? session;
      try {
        session = await ref.read(authRepositoryProvider).restoreSession();
      } catch (_) {
        if (cached != null) {
          final owner = (jsonDecode(cached) as Map)['id'] as String?;
          if (owner != null) await lifecycle.lock(owner);
        }
        _publishLifecycle();
        rethrow;
      }
      if (session == null && cached != null) {
        final owner = (jsonDecode(cached) as Map)['id'] as String?;
        if (owner != null) await lifecycle.lock(owner);
        _publishLifecycle();
      }
      if (session != null &&
          lifecycle.lockedUserId != null &&
          lifecycle.lockedUserId != session.user.id) {
        await ref.read(authRepositoryProvider).signOut();
        return null;
      }
      if (session != null) {
        await lifecycle.lock(session.user.id);
        _publishLifecycle();
        await ref.read(analyticsProvider).setUserId(session.user.id);
        await ref
            .read(entryPreferencesProvider.notifier)
            .initializeAccountPreferences(
              session.user.id,
              activeVehicleId: session.user.activeVehicleId,
            );
        await ref.read(entryPreferencesProvider.notifier).complete();
      }
      return session;
    } finally {
      _restoring = false;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
    String? surface,
  }) async {
    await _awaitRestore();
    final lifecycle = ref.read(accountLifecycleProvider);
    if (lifecycle.cleanupPending) {
      throw const ApiAuthFailure(
        'cleanup_incomplete',
        'Finish clearing local data before signing in',
      );
    }
    final current = state.valueOrNull;
    if (current != null &&
        current.user.email.toLowerCase() != email.trim().toLowerCase()) {
      await signOut();
    }
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
    await _awaitRestore();
    if (ref.read(accountLifecycleProvider).cleanupPending) {
      throw const ApiAuthFailure('cleanup_incomplete');
    }
    if (state.valueOrNull == null &&
        ref.read(accountLifecycleProvider).lockedUserId != null) {
      throw const ApiAuthFailure('account_locked');
    }
    if (state.valueOrNull != null) await signOut();
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
    final lifecycle = ref.read(accountLifecycleProvider);
    final owner = lifecycle.lockedUserId;
    if (lifecycle.cleanupPending ||
        (owner != null && owner != session.user.id)) {
      await ref.read(authRepositoryProvider).signOut();
      throw const ApiAuthFailure(
        'account_locked',
        'Sign in to the previous account to finish syncing and clearing this device',
      );
    }
    await lifecycle.lock(session.user.id);
    _publishLifecycle();
    await ref.read(analyticsProvider).setUserId(session.user.id);
    await ref
        .read(entryPreferencesProvider.notifier)
        .initializeAccountPreferences(
          session.user.id,
          activeVehicleId: session.user.activeVehicleId,
        );
    await ref.read(entryPreferencesProvider.notifier).complete();
    if (isNew) {
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.appMeta)
          .insert(
            AppMetaCompanion.insert(
              key: 'garage_loaded:${session.user.id}',
              value: const Value('true'),
            ),
            onConflict: DoUpdate(
              (_) => const AppMetaCompanion(value: Value('true')),
              target: [db.appMeta.key],
            ),
          );
    }
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
    await _awaitRestore();
    if (ref.read(accountLifecycleProvider).cleanupPending) {
      throw const ApiAuthFailure('cleanup_incomplete');
    }
    final incoming = Session.fromJson(response);
    if (state.valueOrNull != null &&
        state.valueOrNull!.user.id != incoming.user.id) {
      await signOut();
    }
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
    final generation = ref.read(tokenStoreProvider).generation;
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
          expectedGeneration: generation,
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userJson: jsonEncode(user.toJson()),
        );
    state = AsyncData(session);
  }

  void _publishLifecycle() {
    final lifecycle = ref.read(accountLifecycleProvider);
    ref.read(accountLockProvider.notifier).state = lifecycle.lockedUserId;
    ref.read(accountCleanupPendingProvider.notifier).state =
        lifecycle.cleanupPending;
  }

  Future<void> sessionExpired() async {
    final lifecycle = ref.read(accountLifecycleProvider);
    final current = state.valueOrNull;
    try {
      if (current != null) await lifecycle.lock(current.user.id);
    } finally {
      final paused = ref.read(syncAccountCoordinatorProvider).pause();
      state = const AsyncData(null);
      _publishLifecycle();
      await paused;
    }
  }

  Future<void> signOut({bool discardUnsynced = false}) async {
    await _awaitRestore();
    await _withAccountChange(() async {
      final lifecycle = ref.read(accountLifecycleProvider);
      final userId = state.valueOrNull?.user.id ?? lifecycle.lockedUserId;
      if (userId != null) await lifecycle.lock(userId);
      _publishLifecycle();
      if (!discardUnsynced) {
        var pending = await lifecycle.pending();
        if (!pending.isEmpty && state.valueOrNull != null) {
          await ref.read(syncAccountCoordinatorProvider).flush();
          pending = await lifecycle.pending();
        }
        if (!pending.isEmpty) throw LogoutSyncFailure(pending);
      }
      // The pending marker must be durable before credentials or rows disappear.
      lifecycle.cleanupPending = true;
      await lifecycle.journal.write({
        'installed': true,
        'locked_user_id': userId,
        'cleanup_pending': true,
      });
      _publishLifecycle();
      try {
        await ref.read(authRepositoryProvider).signOut();
        state = const AsyncData(null);
        await lifecycle.purge();
        ref.invalidate(organizationDatabaseProvider);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await ref.read(analyticsProvider).setUserId(null);
        ref.read(analyticsProvider).track(AnalyticsEvent.authSignedOut);
        ref.invalidate(entryPreferencesProvider);
        await ref.read(entryPreferencesProvider.future);
        ref.read(postAuthRouteProvider.notifier).state = null;
        ref.read(newOwnerSetupProvider.notifier).state = false;
        ref.read(pendingSocialLinkProvider.notifier).state = null;
        ref.read(pendingCollaborationProvider.notifier).state = null;
      } finally {
        ref.read(accountEpochProvider.notifier).state++;
        state = const AsyncData(null);
        _publishLifecycle();
      }
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
    // Password changes revoke every old session. Establish fresh credentials.
    final email = state.valueOrNull?.user.email;
    if (email != null && email.isNotEmpty) {
      await signIn(email: email, password: newPassword);
    } else {
      state = const AsyncData(null);
    }
  }

  void clearDrivingLicenseFor(String userId) {
    final current = state.valueOrNull;
    if (current == null || current.user.id != userId) return;
    state = AsyncData(
      current.copyWithUser(current.user.copyWith(clearDrivingLicense: true)),
    );
  }

  void updateUser(User user) {
    final current = state.valueOrNull;
    if (current == null || current.user.id != user.id) return;
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

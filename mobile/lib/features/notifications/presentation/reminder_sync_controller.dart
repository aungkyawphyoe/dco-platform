import 'dart:async';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/app_router.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/notifications/data/reminder_sync_service.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps OS local reminders in sync with plan items and mileage.
class ReminderSyncController {
  ReminderSyncController(this._ref);

  final Ref _ref;
  Timer? _debounce;
  StreamSubscription<String>? _taps;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    final client = _ref.read(localNotificationClientProvider);
    await client.initialize();
    if (_disposed) return;
    _taps = client.taps.listen(openPayload);
    final launch = await client.consumeLaunchPayload();
    if (_disposed) return;
    if (launch != null) {
      await openPayload(launch);
    }
    if (_disposed) return;
    schedule();
  }

  void schedule() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_run());
    });
  }

  Future<void> _run() async {
    if (_disposed) return;
    final userId = _ref.read(sessionControllerProvider).valueOrNull?.user.id;
    if (userId == null) return;
    final garage = await _ref.read(vehicleRepositoryProvider).watchGarage(userId).first;
    if (_disposed) return;
    final items = await _ref.read(maintenanceRepositoryProvider).watchAllPlans(userId).first;
    if (_disposed) return;
    final unit = _ref.read(lengthUnitProvider);
    final thresholds = _ref.read(reminderThresholdsProvider);
    final locale = _ref.read(localeProvider);
    await _ref.read(reminderSyncServiceProvider).sync(
      userId: userId,
      garage: garage,
      items: items,
      lengthUnit: unit,
      thresholds: thresholds,
      locale: locale,
    );
  }

  Future<void> openPayload(String payload) async {
    if (_disposed) return;
    final tap = ReminderTap.tryParse(payload);
    if (tap == null) return;
    _ref.read(analyticsProvider).track(AnalyticsEvent.notificationOpened, {
      'plan_item_id': tap.planItemId,
    });
    final userId = await _waitForUserId();
    if (_disposed || userId == null) return;
    final active = await _ref.read(vehicleRepositoryProvider).watchActive(userId).first;
    if (_disposed) return;
    if (active?.id != tap.vehicleId) {
      await _ref.read(vehicleRepositoryProvider).setActive(
        userId: userId,
        vehicleId: tap.vehicleId,
      );
    }
    if (_disposed) return;
    _ref.read(goRouterProvider).go(AppRoutes.maintenance);
  }

  /// The router redirects while the session resolves on cold start, so tap
  /// navigation must wait for a signed-in session or it bounces to splash.
  /// Returns null when the user is signed out or the session fails.
  Future<String?> _waitForUserId({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!_disposed) {
      final session = _ref.read(sessionControllerProvider);
      if (session.hasValue) return session.valueOrNull?.user.id;
      if (session.hasError) return null;
      if (!DateTime.now().isBefore(deadline)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _taps?.cancel();
  }
}

final reminderSyncControllerProvider = Provider<ReminderSyncController>((ref) {
  final controller = ReminderSyncController(ref);
  ref.onDispose(controller.dispose);
  ref.listen(sessionControllerProvider, (_, _) => controller.schedule());
  ref.listen(garageVehiclesProvider, (_, _) => controller.schedule());
  ref.listen(allPlanItemsProvider, (_, _) => controller.schedule());
  ref.listen(lengthUnitProvider, (_, _) => controller.schedule());
  ref.listen(localeProvider, (_, _) => controller.schedule());
  ref.listen(reminderThresholdsProvider, (_, _) => controller.schedule());
  unawaited(controller.start());
  return controller;
});

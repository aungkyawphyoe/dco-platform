// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:ui';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/notifications/local_notification_client.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/notifications/data/reminder_copy.dart';
import 'package:dco_mobile/features/notifications/data/reminder_schedule_store.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_planner.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:dco_mobile/features/notifications/domain/repositories/notification_repository.dart';

class ReminderSyncService {
  ReminderSyncService({
    required LocalNotificationClient notifications,
    required NotificationRepository notificationsRepo,
    required ReminderScheduleStore schedules,
    required Analytics analytics,
  }) : _notifications = notifications,
       _repo = notificationsRepo,
       _schedules = schedules,
       _analytics = analytics;

  final LocalNotificationClient _notifications;
  final NotificationRepository _repo;
  final ReminderScheduleStore _schedules;
  final Analytics _analytics;

  Future<void> sync({
    required String userId,
    required List<Vehicle> garage,
    required List<PlanItem> items,
    required MileageUnit lengthUnit,
    required Locale locale,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final enabledWithDue = items.any(
      (item) =>
          item.enabled && (item.nextDueOn != null || item.nextDueMileage != null),
    );
    var allowed = await _notifications.notificationsAllowed;
    if (enabledWithDue && !await _schedules.permissionAsked) {
      allowed = await _notifications.requestPermissionIfNeeded();
      await _schedules.markPermissionAsked();
    }

    final copy = ReminderCopy(locale);
    await copy.ensureInitialized();

    final delivered = await _repo.deliveredCycleKeys(userId);
    final scheduled = await _schedules.all();
    final actions = ReminderPlanner.plan(
      garage: garage,
      items: items,
      deliveredCycleKeys: delivered,
      scheduled: scheduled,
      now: at,
      lengthUnit: lengthUnit,
    );

    final keepIds = <int>{};
    for (final action in actions) {
      final id = ReminderPolicy.osId(action.planItemId, phase: action.phase);
      final title = copy.title(action.phase);
      final body = copy.body(
        name: action.serviceName,
        dueOn: action.dueOn,
        dueMileage: action.dueMileage,
        unit: lengthUnit,
      );
      switch (action.kind) {
        case ReminderActionKind.cancel:
          await _notifications.cancel(id);
          await _schedules.clear(action.planItemId, action.phase);
        case ReminderActionKind.schedule:
          keepIds.add(id);
          final fireAt = action.fireAt;
          if (fireAt == null) break;
          if (allowed) {
            await _notifications.schedule(
              id: id,
              title: title,
              body: body,
              fireAt: fireAt,
              payload: _payload(action),
            );
          }
          await _schedules.markScheduled(
            planItemId: action.planItemId,
            phase: action.phase,
            cycleKey: action.cycleKey,
            fireAt: fireAt,
          );
        case ReminderActionKind.showNow:
          keepIds.add(id);
          if (allowed) {
            await _notifications.show(
              id: id,
              title: title,
              body: body,
              payload: _payload(action),
            );
            _analytics.track(AnalyticsEvent.notificationShown, {
              'plan_item_id': action.planItemId,
              'phase': action.phase.name,
            });
          }
          await _recordFeed(userId: userId, action: action, title: title, body: body);
          await _schedules.clear(action.planItemId, action.phase);
        case ReminderActionKind.recordFeedOnly:
          keepIds.add(id);
          await _recordFeed(userId: userId, action: action, title: title, body: body);
          await _schedules.clear(action.planItemId, action.phase);
      }
    }

    for (final pending in await _notifications.pendingIds()) {
      if (!keepIds.contains(pending)) {
        await _notifications.cancel(pending);
      }
    }
  }

  Future<void> _recordFeed({
    required String userId,
    required ReminderAction action,
    required String title,
    required String body,
  }) {
    return _repo.recordDue(
      userId: userId,
      vehicleId: action.vehicleId,
      planItemId: action.planItemId,
      cycleKey: action.cycleKey,
      title: title,
      body: body,
      dueReason: action.dueReason,
    );
  }

  String _payload(ReminderAction action) {
    return jsonEncode({
      'vehicleId': action.vehicleId,
      'planItemId': action.planItemId,
      'phase': action.phase.name,
    });
  }
}

class ReminderTap {
  const ReminderTap({required this.vehicleId, required this.planItemId});

  final String vehicleId;
  final String planItemId;

  static ReminderTap? tryParse(String payload) {
    try {
      final json = jsonDecode(payload);
      if (json is! Map) return null;
      final vehicleId = json['vehicleId'] as String?;
      final planItemId = json['planItemId'] as String?;
      if (vehicleId == null || planItemId == null) return null;
      return ReminderTap(vehicleId: vehicleId, planItemId: planItemId);
    } catch (_) {
      return null;
    }
  }
}

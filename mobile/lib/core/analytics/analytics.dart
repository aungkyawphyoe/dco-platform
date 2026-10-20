import 'dart:async';

import 'package:flutter/foundation.dart';

enum AnalyticsEvent {
  authSignedUp('auth_signed_up'),
  authSignedIn('auth_signed_in'),
  authSignedOut('auth_signed_out'),
  authPasswordResetRequested('auth_password_reset_requested'),
  garageOpened('garage_opened'),
  vehicleAdded('vehicle_added'),
  vehicleDeleted('vehicle_deleted'),
  vehicleSwitched('vehicle_switched'),
  vehicleUpdated('vehicle_updated'),
  dashboardOpened('dashboard_opened'),
  dashboardLogServiceTapped('dashboard_log_service_tapped'),
  maintenanceRecordAdded('maintenance_record_added'),
  maintenancePlanItemAdded('maintenance_plan_item_added'),
  maintenanceReminderCompleted('maintenance_reminder_completed'),
  notificationShown('notification_shown'),
  notificationOpened('notification_opened'),
  maintenanceReminderDismissed('maintenance_reminder_dismissed'),
  partAdded('part_added'),
  partUpdated('part_updated'),
  fuelTypeAdded('fuel_type_added'),
  fuelTypeUpdated('fuel_type_updated'),
  fuelLogAdded('fuel_log_added'),
  fuelLogUpdated('fuel_log_updated'),
  expenseAdded('expense_added'),
  expenseUpdated('expense_updated'),
  expenseDeleted('expense_deleted'),
  documentUploaded('document_uploaded'),
  documentOpened('document_opened'),
  documentDeleted('document_deleted'),
  noteAdded('note_added'),
  noteUpdated('note_updated'),
  noteDeleted('note_deleted'),
  statsOpened('stats_opened'),
  statsPeriodChanged('stats_period_changed'),
  statsDefinitionsOpened('stats_definitions_opened');

  const AnalyticsEvent(this.name);
  final String name;
}

/// Destination for analytics events. Implementations must never throw or
/// block the caller — analytics is best-effort and must not affect UX.
abstract interface class AnalyticsSink {
  Future<void> logEvent(String name, Map<String, Object?> parameters);

  Future<void> setUserId(String? userId);

  Future<void> setUserProperty(String name, String? value);

  Future<void> setCollectionEnabled(bool enabled);
}

/// Default sink. Keeps the app running (and tests hermetic) when no
/// analytics backend is configured.
class NoOpAnalyticsSink implements AnalyticsSink {
  const NoOpAnalyticsSink();

  @override
  Future<void> logEvent(String name, Map<String, Object?> parameters) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}

/// Thin facade over an [AnalyticsSink]. Feature code depends on this only,
/// so Firebase never leaks past `core/analytics`.
class Analytics {
  const Analytics([this._sink = const NoOpAnalyticsSink()]);

  final AnalyticsSink _sink;

  void track(
    AnalyticsEvent event, [
    Map<String, Object?> properties = const {},
  ]) {
    if (kDebugMode) {
      debugPrint('[analytics] ${event.name} $properties');
    }
    unawaited(_sink.logEvent(event.name, properties));
  }

  Future<void> setUserId(String? userId) => _sink.setUserId(userId);

  Future<void> setUserProperty(String name, String? value) =>
      _sink.setUserProperty(name, value);

  Future<void> setCollectionEnabled(bool enabled) =>
      _sink.setCollectionEnabled(enabled);
}

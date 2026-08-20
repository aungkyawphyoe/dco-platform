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
  partAdded('part_added'),
  partUpdated('part_updated');

  const AnalyticsEvent(this.name);
  final String name;
}

class Analytics {
  const Analytics();

  void track(AnalyticsEvent event, [Map<String, Object?> properties = const {}]) {
    if (kDebugMode) {
      debugPrint('[analytics] ${event.name} $properties');
    }
  }
}

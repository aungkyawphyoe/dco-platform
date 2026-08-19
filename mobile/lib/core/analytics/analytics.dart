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
  dashboardOpened('dashboard_opened');

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

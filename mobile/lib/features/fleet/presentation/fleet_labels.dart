import 'package:dco_mobile/generated/app_localizations.dart';

String fleetRoleLabel(AppLocalizations s, String role) => switch (role) {
  'org_admin' => s.fleetRoleOrgAdmin,
  'org_manager' => s.fleetRoleOrgManager,
  'org_mechanic' => s.fleetRoleOrgMechanic,
  _ => s.fleetRoleOrgDriver,
};

String fleetOrgStatusLabel(AppLocalizations s, String status) =>
    switch (status) {
      'active' => s.fleetStatusActive,
      'pending' => s.fleetStatusPending,
      'suspended' => s.fleetStatusSuspended,
      _ => s.fleetStatusArchived,
    };

String workOrderStatusLabel(AppLocalizations s, String status) =>
    switch (status) {
      'reported' => s.fleetWoStatusReported,
      'in_progress' => s.fleetWoStatusInProgress,
      _ => s.fleetWoStatusCompleted,
    };

String urgencyLabel(AppLocalizations s, String urgency) => switch (urgency) {
  'low' => s.fleetUrgencyLow,
  'medium' => s.fleetUrgencyMedium,
  'high' => s.fleetUrgencyHigh,
  _ => s.fleetUrgencyCritical,
};

String issueTypeLabel(AppLocalizations s, String issueType) =>
    switch (issueType) {
      'breakdown' => s.fleetIssueBreakdown,
      'accident' => s.fleetIssueAccident,
      'wear_tear' => s.fleetIssueWearTear,
      'scheduled_service' => s.fleetIssueScheduledService,
      _ => s.fleetIssueOther,
    };

String lifecycleLabel(AppLocalizations s, String template) =>
    switch (template) {
      'showroom' => s.fleetVehicleLifecycleShowroom,
      'taxi_fleet' => s.fleetVehicleLifecycleTaxi,
      'rental' => s.fleetVehicleLifecycleRental,
      _ => s.fleetVehicleLifecycleCommercial,
    };

/// Lifecycle status machine — mirror of the server's transition table
/// (`backend/src/modules/fleet.ts`). The server re-validates every change.
const lifecycleTransitions = <String, Map<String, List<String>>>{
  'showroom': {
    'inventory': ['listed'],
    'listed': ['inventory', 'reserved'],
    'reserved': ['listed', 'sold'],
    'sold': [],
  },
  'taxi_fleet': {
    'available': ['leased', 'maintenance'],
    'leased': ['maintenance', 'available'],
    'maintenance': ['available'],
  },
  'rental': {
    'available': ['rented'],
    'rented': ['return'],
    'return': ['inspection'],
    'inspection': ['available'],
  },
  'commercial': {
    'available': ['in_service', 'maintenance'],
    'in_service': ['maintenance', 'retired'],
    'maintenance': ['available', 'in_service', 'retired'],
    'retired': [],
  },
};

/// Lifecycle statuses are free-form per template — show known values
/// localized, otherwise the raw status.
String vehicleStatusLabel(AppLocalizations s, String status) =>
    switch (status) {
      'available' => s.fleetStatusActive,
      'inventory' => s.fleetStatusPending,
      'retired' => s.fleetStatusArchived,
      _ => status.replaceAll('_', ' '),
    };

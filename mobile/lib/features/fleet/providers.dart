import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/fleet/data/repositories/fleet_repository_impl.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_assignment.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization_member.dart';
import 'package:dco_mobile/features/fleet/domain/entities/org_vehicle.dart';
import 'package:dco_mobile/features/fleet/domain/entities/shift_mileage.dart';
import 'package:dco_mobile/features/fleet/domain/entities/vehicle_cost.dart';
import 'package:dco_mobile/features/fleet/domain/entities/warranty_template.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';

final fleetRepositoryProvider = Provider<FleetRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  return FleetRepositoryImpl(dio, db, userId);
});

/// `GET /v1/me/entitlements` — navigation hints for conditional drawer
/// entries. Rebuilt when the signed-in user changes.
final entitlementsProvider = FutureProvider<Entitlements>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('No signed-in user');
  return ref.watch(fleetRepositoryProvider).getEntitlements();
});

/// `GET /v1/organizations/me` — organization context for Fleet mode.
final myOrganizationProvider = FutureProvider<MyOrganization>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('No signed-in user');
  return ref.watch(fleetRepositoryProvider).getMyOrganization();
});

// ---------------------------------------------------------------------------
// Mode switch (Personal / Fleet / Driver)
// ---------------------------------------------------------------------------

class FleetModeController extends AsyncNotifier<FleetMode> {
  @override
  Future<FleetMode> build() =>
      ref.watch(fleetRepositoryProvider).getStoredMode();

  Future<void> setMode(FleetMode mode) async {
    await ref.read(fleetRepositoryProvider).setStoredMode(mode);
    state = AsyncData(mode);
  }
}

final storedFleetModeProvider =
    AsyncNotifierProvider<FleetModeController, FleetMode>(
  FleetModeController.new,
);

/// Effective navigation mode: the stored preference validated against live
/// entitlements. Presentation-only — it degrades to `personal` whenever
/// fleet access or the expected role is not confirmed. Every Fleet request
/// re-checks access server-side.
final fleetModeProvider = Provider<FleetMode>((ref) {
  final stored =
      ref.watch(storedFleetModeProvider).valueOrNull ?? FleetMode.personal;
  if (stored == FleetMode.personal) return FleetMode.personal;

  final entitlements = ref.watch(entitlementsProvider).valueOrNull;
  if (entitlements == null) return stored;
  if (!entitlements.canUseFleet) return FleetMode.personal;

  final org = entitlements.organization!;
  if (org.isDriver) {
    return stored == FleetMode.driver ? FleetMode.driver : FleetMode.personal;
  }
  return stored == FleetMode.fleet ? FleetMode.fleet : FleetMode.personal;
});

// ---------------------------------------------------------------------------
// Organization data (online-first)
// ---------------------------------------------------------------------------

final orgMembersProvider =
    FutureProvider.family<List<OrgMember>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getMembers(orgId);
});

final orgVehiclesProvider =
    FutureProvider.family<List<OrgVehicle>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getVehicles(orgId);
});

final orgWorkshopsProvider =
    FutureProvider.family<List<OrgWorkshop>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getWorkshops(orgId);
});

final assignmentsProvider =
    FutureProvider.family<List<DriverAssignment>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getAssignments(orgId);
});

final orgWorkOrdersProvider =
    FutureProvider.family<List<WorkOrder>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getWorkOrders(orgId);
});

final orgInspectionsProvider =
    FutureProvider.family<List<Inspection>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getInspections(orgId);
});

final inspectionTemplatesProvider =
    FutureProvider.family<List<InspectionTemplate>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getInspectionTemplates(orgId);
});

final shiftMileageProvider =
    FutureProvider.family<List<ShiftMileage>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getShiftMileage(orgId);
});

final fleetAnalyticsProvider =
    FutureProvider.family<FleetAnalytics, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getFleetAnalytics(orgId);
});

final lemonsProvider =
    FutureProvider.family<LemonReport, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getLemons(orgId);
});

final vehicleCostProvider =
    FutureProvider.family<VehicleCost, (String, String)>((ref, ids) {
  return ref.watch(fleetRepositoryProvider).getVehicleCost(ids.$1, ids.$2);
});

final warrantyTemplatesProvider =
    FutureProvider.family<List<WarrantyTemplate>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getWarrantyTemplates(orgId);
});

// ---------------------------------------------------------------------------
// Driver surface
// ---------------------------------------------------------------------------

final driverMyVehicleProvider = FutureProvider<DriverMyVehicle>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('No signed-in user');
  return ref.watch(fleetRepositoryProvider).getDriverMyVehicle();
});

final driverWorkOrdersProvider = FutureProvider<List<WorkOrder>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('No signed-in user');
  return ref.watch(fleetRepositoryProvider).getDriverWorkOrders();
});

final driverInspectionsProvider = FutureProvider<List<Inspection>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('No signed-in user');
  return ref.watch(fleetRepositoryProvider).getDriverInspections();
});

/// The signed-in user's local fuel-type catalog (drivers log org fuel with
/// their own fuel types; seeds defaults on first read).
final driverFuelCatalogProvider = StreamProvider<List<FuelCatalogType>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  final repository = ref.watch(fuelRepositoryProvider);
  repository.ensureDefaultFuelTypes(userId);
  return repository.watchFuelTypes(userId);
});

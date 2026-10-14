import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/fleet/data/repositories/fleet_repository_impl.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/shift_mileage.dart';
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

/// Effective navigation mode, derived from live entitlements — no stored
/// preference. `org_driver` accounts are forced into Driver mode (no personal
/// garage, no toggle); everyone else stays in the personal garage. Fleet
/// management lives on the Fleet Portal. Server-side role checks remain
/// authoritative.
final fleetModeProvider = Provider<FleetMode>((ref) {
  final entitlements = ref.watch(entitlementsProvider).valueOrNull;
  final org = entitlements?.organization;
  if (org != null && org.isDriver) return FleetMode.driver;
  return FleetMode.personal;
});

// ---------------------------------------------------------------------------
// Driver surface (online-first)
// ---------------------------------------------------------------------------

final inspectionTemplatesProvider =
    FutureProvider.family<List<InspectionTemplate>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getInspectionTemplates(orgId);
});

final shiftMileageProvider =
    FutureProvider.family<List<ShiftMileage>, String>((ref, orgId) {
  return ref.watch(fleetRepositoryProvider).getShiftMileage(orgId);
});

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

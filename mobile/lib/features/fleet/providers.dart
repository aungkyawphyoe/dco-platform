import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/fleet/data/repositories/fleet_repository_impl.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';

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
// Supplemental fleet workflows (online-only)
// ---------------------------------------------------------------------------

final inspectionTemplatesProvider =
    FutureProvider.family<List<InspectionTemplate>, String>((ref, orgId) {
      return ref.watch(fleetRepositoryProvider).getInspectionTemplates(orgId);
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

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/suggested_plan_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/sync_engine.dart';

final allPlanItemsProvider = StreamProvider<List<PlanItem>>((ref) {
  final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
  if (userId == null) return Stream.value(const []);
  return ref.watch(maintenanceRepositoryProvider).watchAllPlans(userId);
});

final maintenancePlanProvider = StreamProvider<List<PlanItem>>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(const []);
  return ref.watch(maintenanceRepositoryProvider).watchPlan(vehicleId);
});

final maintenanceHistoryProvider = StreamProvider<List<ServiceRecord>>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(const []);
  return ref.watch(maintenanceRepositoryProvider).watchHistory(vehicleId);
});

/// Same data as [maintenancePlanProvider], keyed by an explicit vehicle id
/// so screens can render for a vehicle that is not the active one.
final maintenancePlanForVehicleProvider =
    StreamProvider.family<List<PlanItem>, String>((ref, vehicleId) {
      if (vehicleId.isEmpty) return Stream.value(const []);
      return ref.watch(maintenanceRepositoryProvider).watchPlan(vehicleId);
    });

/// Same data as [maintenanceHistoryProvider], keyed by an explicit vehicle id.
final maintenanceHistoryForVehicleProvider =
    StreamProvider.family<List<ServiceRecord>, String>((ref, vehicleId) {
      if (vehicleId.isEmpty) return Stream.value(const []);
      return ref.watch(maintenanceRepositoryProvider).watchHistory(vehicleId);
    });

typedef MaintenanceScope = ({String userId, String vehicleId});

final suggestedItemsProvider = StreamProvider.autoDispose
    .family<List<SuggestedPlanItem>?, MaintenanceScope>((ref, scope) {
      return ref
          .watch(maintenanceCatalogRepositoryProvider)
          .watchForVehicle(scope.vehicleId);
    });

final suggestedVehiclePlanProvider = StreamProvider.autoDispose
    .family<List<PlanItem>, MaintenanceScope>((ref, scope) {
      return ref
          .watch(maintenanceRepositoryProvider)
          .watchPlan(scope.vehicleId);
    });

/// Refresh on identity/vehicle changes and successful sync (including the first
/// push of a newly created vehicle). The screen always reads the local cache.
final maintenanceCatalogRefreshProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final vehicle = ref.watch(activeVehicleProvider).asData?.value;
  ref.watch(driverOrganizationIdProvider);
  ref.listen(syncStatusProvider, (previous, next) {
    final completed = next.asData?.value;
    if (completed?.phase == SyncPhase.idle &&
        completed?.lastSyncedAt != null &&
        completed!.lastSyncedAt != previous?.asData?.value.lastSyncedAt) {
      ref.invalidateSelf();
    }
  });
  if (userId == null || vehicle == null) return true;
  final repository = ref.watch(maintenanceCatalogRepositoryProvider);
  try {
    await repository.fetchAndCache(vehicle.id);
    return true;
  } catch (_) {
    // Keep cached data usable; report failure without an unobserved async error.
    return false;
  }
});

final serviceDetailProvider = FutureProvider.family<ServiceRecord?, String>((
  ref,
  id,
) {
  return ref.watch(maintenanceRepositoryProvider).getServiceRecord(id);
});

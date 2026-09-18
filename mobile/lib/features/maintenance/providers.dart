import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/suggested_plan_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final suggestedItemsProvider = StreamProvider<List<SuggestedPlanItem>>((ref) {
  final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
  if (vehicle == null) return Stream.value(const []);
  return ref.watch(maintenanceCatalogRepositoryProvider).watchByFuelType(vehicle.fuelType);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/family/data/repositories/family_repository_impl.dart';
import 'package:dco_mobile/features/family/domain/repositories/family_repository.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart' as family_entities;

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  final outbox = ref.watch(outboxWriterProvider);
  return FamilyRepositoryImpl(dio, db, outbox);
});

final myFamilyProvider = FutureProvider<family_entities.Family?>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getMyFamily();
});

final familyMembersProvider = FutureProvider<List<family_entities.FamilyMember>>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getMembers();
});

final vehicleDetailProvider = FutureProvider.family<family_entities.FamilyVehicleDetail?, String>((ref, vehicleId) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getVehicleDetail(vehicleId);
});

final userDetailProvider = FutureProvider.family<family_entities.UserDetail?, String>((ref, userId) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getUserDetail(userId);
});

final myLicenseProvider = FutureProvider<family_entities.DrivingLicense?>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getMyLicense();
});

final vehicleDetailAsyncProvider = Provider.family<AsyncValue<family_entities.FamilyVehicleDetail?>, String>((ref, vehicleId) {
  return ref.watch(vehicleDetailProvider(vehicleId));
});

/// Local-first vehicle detail: reads from Drift immediately, then
/// enriches with API data (grants, documents, assigned drivers).
final localVehicleDetailProvider = FutureProvider.family<family_entities.FamilyVehicleDetail?, String>((ref, vehicleId) async {
  final repo = ref.watch(familyRepositoryProvider);

  // Step 1: load from local Drift
  final local = await repo.getLocalVehicleDetail(vehicleId);

  // Step 2: fire-and-forget API enrich (grants, docs, drivers)
  // ignore: unawaited_futures
  repo.getVehicleDetail(vehicleId).then((remote) {
    if (remote != null) {
      ref.invalidate(vehicleDetailProvider(vehicleId));
    }
  });

  return local;
});

/// Local-first user detail: reads from Drift immediately, then
/// enriches with API data (email, plan, vehicleLimit, etc.).
final localUserDetailProvider = FutureProvider.family<family_entities.UserDetail?, String>((ref, userId) async {
  final repo = ref.watch(familyRepositoryProvider);

  // Step 1: load from local Drift
  final local = await repo.getLocalUserDetail(userId);

  // Step 2: fire-and-forget API enrich
  // ignore: unawaited_futures
  repo.getUserDetail(userId).then((remote) {
    if (remote != null) {
      ref.invalidate(userDetailProvider(userId));
    }
  });

  return local;
});

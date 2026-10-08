import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/presentation/session_controller.dart';
import 'data/repositories/vehicle_share_repository_impl.dart';
import 'domain/entities/user_detail.dart';
import 'domain/entities/vehicle_share.dart';
import 'domain/repositories/vehicle_share_repository.dart';

final vehicleShareRepositoryProvider = Provider<VehicleShareRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  return VehicleShareRepositoryImpl(dio, db);
});

/// Owner-side sharing state for one vehicle: active shares, pending
/// invitations, the current code, and the plan caps.
final vehicleSharesProvider = FutureProvider.autoDispose
    .family<VehicleSharesDetail?, String>((ref, vehicleId) async {
      if (vehicleId.isEmpty) return null;
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return null;
      return ref.watch(vehicleShareRepositoryProvider).listShares(vehicleId);
    });

/// Vehicles shared *with* the current user.
final sharedVehiclesProvider = FutureProvider<List<SharedVehicle>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(vehicleShareRepositoryProvider).listSharedVehicles();
});

/// Profile of yourself or of someone you share a vehicle with.
final userDetailProvider = FutureProvider.family<UserDetail?, String>((
  ref,
  userId,
) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return null;
  return ref.watch(vehicleShareRepositoryProvider).getUserDetail(userId);
});

/// Resolves a human-readable name for [userId] to label who logged a record.
///
/// Resolution order: your own session profile, then locally cached share rows
/// (works offline for people you share vehicles with), then the network
/// profile. Null when the name cannot be resolved — callers show a dash.
final userNameProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (userId == currentUserId) {
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user?.email;
  }
  final cached = await ref.watch(vehicleShareRepositoryProvider).cachedUserName(userId);
  if (cached != null) return cached;
  try {
    final detail = await ref.watch(userDetailProvider(userId).future);
    if (detail != null) {
      final name = detail.displayName?.trim();
      if (name != null && name.isNotEmpty) return name;
      return detail.email;
    }
  } catch (_) {
    // Offline or transient failure — fall through to null.
  }
  return null;
});

/// Preview of a share code before the user commits to joining.
final sharePreviewProvider = FutureProvider.autoDispose
    .family<SharePreview?, String>((ref, code) async {
      final trimmed = code.trim().toUpperCase();
      if (trimmed.length != 8) return null;
      return ref.watch(vehicleShareRepositoryProvider).previewCode(trimmed);
    });

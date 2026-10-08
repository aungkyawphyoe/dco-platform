import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/entities/vehicle_share.dart';

export 'package:dco_mobile/features/vehicle_sharing/domain/entities/vehicle_share.dart'
    show ShareAccessLevel;

/// The caller's effective permissions on a single vehicle.
///
/// Mirrors the sharing matrix in `product/frd/vehicle-sharing.md`:
/// the owner manages the vehicle, its shares, and the maintenance plan and may
/// edit any record on it; an `add_edit_own` sharee contributes records and
/// keeps control of the ones they created; a `view` sharee is read-only.
/// The API remains authoritative — this exists to keep unavailable actions
/// out of the UI instead of surfacing 403s.
class VehicleAccess {
  const VehicleAccess._({required this.role, required this.currentUserId});

  final VehicleRole role;
  final String? currentUserId;

  /// Derives permissions for [currentUserId] on [vehicle].
  ///
  /// A missing vehicle or user yields no permissions (the read-only role), so
  /// screens degrade to hiding write affordances rather than guessing.
  factory VehicleAccess.of(Vehicle? vehicle, String? currentUserId) {
    if (vehicle == null || currentUserId == null) {
      return const VehicleAccess._(role: VehicleRole.viewer, currentUserId: null);
    }
    if (vehicle.userId == currentUserId) {
      return VehicleAccess._(role: VehicleRole.owner, currentUserId: currentUserId);
    }
    final role = vehicle.accessLevel == ShareAccessLevel.addEditOwn
        ? VehicleRole.contributor
        : VehicleRole.viewer;
    return VehicleAccess._(role: role, currentUserId: currentUserId);
  }

  bool get isOwner => role == VehicleRole.owner;

  /// Edit vehicle identity, archive it, or manage shares.
  bool get canManageVehicle => isOwner;

  /// Create, edit, or delete maintenance plan items.
  bool get canManagePlan => isOwner;

  /// Create new records (service, expense, fuel log, document, part).
  bool get canCreate => role != VehicleRole.viewer;

  /// Edit or delete an existing record: the owner controls every record on
  /// their vehicle; a sharee only records they created.
  bool canEditRecord(String? createdBy) {
    if (isOwner) return true;
    if (!canCreate) return false;
    final me = currentUserId;
    if (me == null || createdBy == null) return false;
    return createdBy == me;
  }
}

enum VehicleRole { owner, contributor, viewer }

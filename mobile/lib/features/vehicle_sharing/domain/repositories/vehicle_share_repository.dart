import 'package:dco_mobile/features/vehicle_sharing/domain/entities/user_detail.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/entities/vehicle_share.dart';

/// Vehicle sharing: per-vehicle access granted to other users by email
/// invitation or by share code/QR.
///
/// Contract: `architecture/openapi.yaml` → `/v1/vehicles/{id}/shares`.
abstract class VehicleShareRepository {
  /// Owner creates a share — `method: email` sends an invitation,
  /// `method: code_qr` mints (and rotates) the vehicle's share code.
  Future<CreatedShare> createShare({
    required String vehicleId,
    required ShareMethod method,
    String? email,
    ShareAccessLevel accessLevel = ShareAccessLevel.view,
  });

  /// Owner-side state for one vehicle. Falls back to the local share rows
  /// when the network is unavailable.
  Future<VehicleSharesDetail?> listShares(String vehicleId);

  /// Change an active share's access level, or rotate the vehicle's
  /// share code when [regenerateCode] is set.
  Future<VehicleShare> updateShare({
    required String vehicleId,
    required String shareId,
    ShareAccessLevel? accessLevel,
    bool regenerateCode = false,
  });

  Future<void> revokeShare({
    required String vehicleId,
    required String shareId,
  });

  /// Re-issue a pending email invitation with a fresh token + expiry.
  Future<ShareInvitation> resendInvite({
    required String vehicleId,
    required ShareInvitation invitation,
  });

  /// Withdraw a pending invitation (and its placeholder share row).
  Future<void> cancelInvite({
    required String vehicleId,
    required ShareInvitation invitation,
  });

  /// Vehicles shared *with* the current user.
  Future<List<SharedVehicle>> listSharedVehicles();

  /// Email flow: accept an invitation by its opaque token.
  Future<VehicleShare> acceptInvite(String token);

  /// Code/QR flow: join using an 8-character share code.
  Future<VehicleShare> joinByCode(String code);

  Future<void> declineInvite(String token);

  /// Look up a code before committing to join.
  Future<SharePreview?> previewCode(String code);

  /// Profile of someone you share a vehicle with (or yourself).
  Future<UserDetail?> getUserDetail(String userId);

  /// Wipes local share rows on sign-out.
  Future<void> clearCache();
}

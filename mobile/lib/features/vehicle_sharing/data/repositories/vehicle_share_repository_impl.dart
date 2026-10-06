import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/app_database.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/vehicle_share.dart';
import '../../domain/repositories/vehicle_share_repository.dart';

class VehicleShareRepositoryImpl implements VehicleShareRepository {
  VehicleShareRepositoryImpl(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  @override
  Future<CreatedShare> createShare({
    required String vehicleId,
    required ShareMethod method,
    String? email,
    ShareAccessLevel accessLevel = ShareAccessLevel.view,
  }) async {
    final response = await _dio.post(
      '/vehicles/$vehicleId/shares',
      data: {
        'method': method.storage,
        'access_level': accessLevel.storage,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    final created = CreatedShare.fromJson(
      response.data as Map<String, dynamic>,
    );
    await refresh(vehicleId);
    return created;
  }

  @override
  Future<VehicleSharesDetail?> listShares(String vehicleId) async {
    try {
      final response = await _dio.get('/vehicles/$vehicleId/shares');
      final detail = VehicleSharesDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _cacheShares(detail);
      return detail;
    } catch (error) {
      if (error is DioException &&
          (error.response?.statusCode == 403 ||
              error.response?.statusCode == 404)) {
        return null;
      }
      return _cachedShares(vehicleId);
    }
  }

  /// Re-reads the owner view after a mutation so callers can invalidate.
  Future<void> refresh(String vehicleId) async {
    final response = await _dio.get('/vehicles/$vehicleId/shares');
    await _cacheShares(
      VehicleSharesDetail.fromJson(response.data as Map<String, dynamic>),
    );
  }

  @override
  Future<VehicleShare> updateShare({
    required String vehicleId,
    required String shareId,
    ShareAccessLevel? accessLevel,
    bool regenerateCode = false,
  }) async {
    final response = await _dio.patch(
      '/vehicles/$vehicleId/shares/$shareId',
      data: {
        if (accessLevel != null) 'access_level': accessLevel.storage,
        if (regenerateCode) 'regenerate_code': true,
      },
    );
    await refresh(vehicleId);
    return VehicleShare.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> revokeShare({
    required String vehicleId,
    required String shareId,
  }) async {
    await _dio.delete('/vehicles/$vehicleId/shares/$shareId');
    await (_db.delete(
      _db.vehicleShareRecords,
    )..where((row) => row.id.equals(shareId))).go();
    await refresh(vehicleId);
  }

  @override
  Future<ShareInvitation> resendInvite({
    required String vehicleId,
    required ShareInvitation invitation,
  }) async {
    final response = await _dio.post(
      '/vehicles/$vehicleId/invitations/${invitation.id}/resend',
    );
    await refresh(vehicleId);
    return ShareInvitation.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<void> cancelInvite({
    required String vehicleId,
    required ShareInvitation invitation,
  }) async {
    await _dio.delete('/vehicles/$vehicleId/invitations/${invitation.id}');
    await (_db.delete(
      _db.vehicleShareInvitationRecords,
    )..where((row) => row.id.equals(invitation.id))).go();
    await refresh(vehicleId);
  }

  @override
  Future<List<SharedVehicle>> listSharedVehicles() async {
    try {
      final response = await _dio.get('/vehicles/shared');
      final items = ((response.data as Map<String, dynamic>)['items'] as List?)
              ?.toList() ??
          const [];
      return items
          .map((e) => SharedVehicle.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _cachedSharedVehicles();
    }
  }

  @override
  Future<VehicleShare> acceptInvite(String token) async {
    final response = await _dio.post(
      '/vehicles/shares/accept',
      data: {'token': token},
    );
    return VehicleShare.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<VehicleShare> joinByCode(String code) async {
    final response = await _dio.post(
      '/vehicles/shares/join',
      data: {'code': code.toUpperCase()},
    );
    return VehicleShare.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> declineInvite(String token) async {
    await _dio.post('/vehicles/shares/decline', data: {'token': token});
  }

  @override
  Future<SharePreview?> previewCode(String code) async {
    try {
      final response = await _dio.get(
        '/vehicles/shares/${code.toUpperCase()}',
      );
      return SharePreview.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 410) return null;
      throw mapDioError(error);
    }
  }

  @override
  Future<UserDetail?> getUserDetail(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/detail');
      return UserDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 403) return null;
      throw mapDioError(error);
    }
  }

  @override
  Future<void> clearCache() async {
    await _db.delete(_db.vehicleShareRecords).go();
    await _db.delete(_db.vehicleShareInvitationRecords).go();
  }

  // ─── Local cache ────────────────────────────────────────────────

  Future<void> _cacheShares(VehicleSharesDetail detail) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.vehicleShareRecords,
      )..where((row) => row.vehicleId.equals(detail.vehicleId))).go();
      for (final share in detail.shares) {
        await _db
            .into(_db.vehicleShareRecords)
            .insertOnConflictUpdate(
              VehicleShareRecordsCompanion.insert(
                id: share.id,
                vehicleId: detail.vehicleId,
                userId: share.userId,
                grantedBy: drift.Value(share.grantedBy),
                accessLevel: share.accessLevel.storage,
                status: drift.Value(share.status.storage),
                invitedEmail: drift.Value(share.invitedEmail),
                shareCode: drift.Value(share.shareCode),
                displayName: drift.Value(share.displayName),
                email: drift.Value(share.email),
                acceptedAt: drift.Value(share.acceptedAt),
                createdAt: share.createdAt,
                syncedAt: drift.Value(
                  DateTime.now().toUtc().toIso8601String(),
                ),
              ),
            );
      }

      await (_db.delete(
        _db.vehicleShareInvitationRecords,
      )..where((row) => row.vehicleId.equals(detail.vehicleId))).go();
      for (final invite in detail.pendingInvites) {
        await _db
            .into(_db.vehicleShareInvitationRecords)
            .insertOnConflictUpdate(
              VehicleShareInvitationRecordsCompanion.insert(
                id: invite.id,
                vehicleId: detail.vehicleId,
                invitedEmail: drift.Value(invite.invitedEmail),
                invitedBy: '',
                accessLevel: invite.accessLevel.storage,
                shareCode: drift.Value(invite.shareCode),
                expiresAt: invite.expiresAt,
                acceptedAt: drift.Value(invite.acceptedAt),
                createdAt: invite.createdAt,
                syncedAt: drift.Value(
                  DateTime.now().toUtc().toIso8601String(),
                ),
              ),
            );
      }
    });
  }

  Future<VehicleSharesDetail?> _cachedShares(String vehicleId) async {
    final vehicle = await (_db.select(
      _db.vehicleRecords,
    )..where((row) => row.id.equals(vehicleId))).getSingleOrNull();
    if (vehicle == null) return null;

    final shareRows = await (_db.select(
      _db.vehicleShareRecords,
    )..where((row) => row.vehicleId.equals(vehicleId))).get();
    final inviteRows = await (_db.select(
      _db.vehicleShareInvitationRecords,
    )..where((row) => row.vehicleId.equals(vehicleId))).get();

    return VehicleSharesDetail(
      vehicleId: vehicleId,
      vehicleName: vehicle.nickname?.isNotEmpty == true
          ? vehicle.nickname!
          : vehicle.name,
      licensePlate: vehicle.licensePlate,
      shares: shareRows
          .map(
            (row) => VehicleShare(
              id: row.id,
              vehicleId: row.vehicleId,
              userId: row.userId,
              grantedBy: row.grantedBy,
              accessLevel: ShareAccessLevel.parse(row.accessLevel),
              status: ShareStatus.parse(row.status),
              createdAt: row.createdAt,
              invitedEmail: row.invitedEmail,
              shareCode: row.shareCode,
              acceptedAt: row.acceptedAt,
              displayName: row.displayName,
              email: row.email,
            ),
          )
          .toList(),
      pendingInvites: inviteRows
          .map(
            (row) => ShareInvitation(
              id: row.id,
              vehicleId: row.vehicleId,
              invitedEmail: row.invitedEmail,
              accessLevel: ShareAccessLevel.parse(row.accessLevel),
              shareCode: row.shareCode,
              expiresAt: row.expiresAt,
              createdAt: row.createdAt,
              acceptedAt: row.acceptedAt,
            ),
          )
          .toList(),
      limits: const ShareLimits(perVehicle: 1, total: 3),
    );
  }

  Future<List<SharedVehicle>> _cachedSharedVehicles() async {
    final rows = await _db.select(_db.vehicleShareRecords).get();
    final shared = rows
        .where((row) => row.status == ShareStatus.active.storage)
        .toList();
    if (shared.isEmpty) return const [];

    final vehicles = await (_db.select(
      _db.vehicleRecords,
    )..where(
        (row) => row.id.isIn(shared.map((s) => s.vehicleId).toList()),
      ))
        .get();
    final byId = {for (final vehicle in vehicles) vehicle.id: vehicle};

    final result = <SharedVehicle>[];
    for (final share in shared) {
      final vehicle = byId[share.vehicleId];
      if (vehicle == null) continue;
      result.add(
        SharedVehicle(
          id: vehicle.id,
          userId: vehicle.userId,
          name: vehicle.name,
          nickname: vehicle.nickname,
          make: vehicle.make,
          model: vehicle.model,
          year: vehicle.year,
          licensePlate: vehicle.licensePlate,
          vin: vehicle.vin,
          color: vehicle.color,
          fuelType: vehicle.fuelType,
          mileage: vehicle.mileage,
          mileageUnit: vehicle.mileageUnit,
          archived: vehicle.archived,
          updatedAt: vehicle.updatedAt,
          createdAt: vehicle.createdAt,
          accessLevel: ShareAccessLevel.parse(share.accessLevel),
          ownerId: vehicle.userId,
        ),
      );
    }
    return result;
  }
}

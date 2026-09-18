import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/family/data/mappers/family_mappers.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart';
import 'package:dco_mobile/features/family/domain/repositories/family_repository.dart';
import 'package:dco_mobile/features/garage/data/mappers/vehicle_mapper.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  final Dio _dio;
  final AppDatabase _db;
  final OutboxWriter _outbox;

  FamilyRepositoryImpl(this._dio, this._db, this._outbox);

  @override
  Future<Family?> getMyFamily() async {
    try {
      final response = await _dio.get('/families/me');
      final family = Family.fromJson(response.data);
      await _cacheFamily(family);
      return family;
    } catch (e) {
      return _getCachedFamily();
    }
  }

  @override
  Future<Family> createFamily(String name) async {
    final response = await _dio.post('/families', data: {'name': name});
    final family = Family.fromJson(response.data);
    await _cacheFamily(family);
    return family;
  }

  @override
  Future<Family> joinFamily(String code) async {
    final response = await _dio.post('/families/me/join', data: {'code': code});
    final family = Family.fromJson(response.data);
    await _cacheFamily(family);
    return family;
  }

  @override
  Future<Family> updateFamily({
    String? name,
    bool regenerateShareCode = false,
  }) async {
    final response = await _dio.patch(
      '/families/me',
      data: {
        if (name != null) 'name': name,
        'regenerate_share_code': regenerateShareCode,
      },
    );
    final family = Family.fromJson(response.data);
    await _cacheFamily(family);
    return family;
  }

  @override
  Future<void> archiveFamily() async {
    await _dio.delete('/families/me');
    await clearFamilyCache();
  }

  @override
  Future<List<FamilyMember>> getMembers() async {
    try {
      final response = await _dio.get('/families/me/members');
      return (response.data as List)
          .map((e) => FamilyMember.fromJson(e))
          .toList();
    } catch (e) {
      return _getCachedMembers();
    }
  }

  @override
  Future<FamilyMember> updateMemberRole(String userId, String role) async {
    final response = await _dio.patch(
      '/families/me/members/$userId',
      data: {'role': role},
    );
    return FamilyMember.fromJson(response.data);
  }

  @override
  Future<void> removeMember(String userId) async {
    await _dio.delete('/families/me/members/$userId');
  }

  @override
  Future<VehicleGrant> grantVehicleAccess(
    String vehicleId,
    String userId,
    String permission,
  ) async {
    final response = await _dio.post(
      '/families/me/vehicle-grants',
      data: {
        'vehicle_id': vehicleId,
        'user_id': userId,
        'permission': permission,
      },
    );
    return VehicleGrant.fromJson(response.data);
  }

  @override
  Future<void> revokeVehicleGrant(String grantId) async {
    await _dio.delete('/families/me/vehicle-grants/$grantId');
  }

  @override
  Future<List<FamilyVehicle>> getFamilyVehicles() async {
    try {
      final response = await _dio.get('/families/me/vehicles');
      final items = (response.data['items'] as List)
          .map((e) => FamilyVehicle.fromJson(e as Map<String, dynamic>))
          .toList();
      // Cache family vehicles locally
      for (final fv in items) {
        await _cacheFamilyVehicle(fv);
      }
      return items;
    } catch (e) {
      return _getCachedFamilyVehicles();
    }
  }

  @override
  Future<void> addVehicleToFamily(String vehicleId) async {
    await _dio.post('/families/me/vehicles', data: {'vehicle_id': vehicleId});
  }

  @override
  Future<void> removeVehicleFromFamily(String vehicleId) async {
    await _dio.delete('/families/me/vehicles/$vehicleId');
    // Remove from local cache
    await (_db.delete(_db.familyVehicleRecords)
          ..where((r) => r.vehicleId.equals(vehicleId)))
        .go();
  }

  @override
  Future<DrivingLicense?> getMyLicense() async {
    try {
      final response = await _dio.get('/users/me/license');
      return DrivingLicense.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<DrivingLicense> upsertLicense({
    String? licenseNumber,
    String? issuingCountry,
    required String expiryDate,
    String? categories,
    String? frontMediaId,
    String? backMediaId,
  }) async {
    final response = await _dio.put(
      '/users/me/license',
      data: {
        'license_number': licenseNumber,
        'issuing_country': issuingCountry,
        'expiry_date': expiryDate,
        'categories': categories,
        'front_media_id': frontMediaId,
        'back_media_id': backMediaId,
      },
    );
    return DrivingLicense.fromJson(response.data);
  }

  @override
  Future<String> uploadLicenseMedia(String side, List<int> bytes) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: 'license_$side.jpg'),
      'side': side,
    });
    final response = await _dio.post('/users/me/license/media', data: formData);
    return response.data['media_id'] as String;
  }

  @override
  Future<DrivingLicense?> getMemberLicense(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/license');
      return DrivingLicense.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<FamilyVehicleDetail?> getVehicleDetail(String vehicleId) async {
    try {
      final response = await _dio.get('/vehicles/$vehicleId/detail');
      return FamilyVehicleDetail.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserDetail?> getUserDetail(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/detail');
      return UserDetail.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<FamilyVehicleDetail?> getLocalVehicleDetail(String vehicleId) async {
    final row = await (_db.select(
      _db.vehicleRecords,
    )..where((r) => r.id.equals(vehicleId))).getSingleOrNull();
    if (row == null) return null;

    final vehicle = vehicleFromDrift(row);
    return FamilyVehicleDetail(
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
      fuelType: vehicle.fuelType.storage,
      mileage: vehicle.mileage,
      mileageUnit: vehicle.mileageUnit.name,
      purchaseDate: vehicle.purchaseDate?.toIso8601String().split('T').first,
      purchasePrice: vehicle.purchasePrice,
      photoMediaId: vehicle.photoMediaId,
      archived: vehicle.archived,
      archivedAt: vehicle.archivedAt?.toIso8601String(),
      updatedAt: vehicle.updatedAt,
      grants: const [],
      documents: const [],
      assignedDrivers: const [],
    );
  }

  @override
  Future<UserDetail?> getLocalUserDetail(String userId) async {
    final profile = await (_db.select(
      _db.userProfiles,
    )..where((r) => r.userId.equals(userId))).getSingleOrNull();

    final licenseRow = await (_db.select(
      _db.drivingLicenseRecords,
    )..where((r) => r.userId.equals(userId))).getSingleOrNull();

    final membershipRow = await (_db.select(
      _db.familyMembershipRecords,
    )..where((r) => r.userId.equals(userId))).getSingleOrNull();

    final vehicleRows = await (_db.select(
      _db.vehicleRecords,
    )..where((r) => r.userId.equals(userId) & r.archived.equals(false))).get();

    final familyId = membershipRow?.familyId;

    return UserDetail(
      id: userId,
      email: '',
      role: 'owner',
      plan: 'free',
      status: 'active',
      emailVerified: true,
      activeVehicleId: profile?.activeVehicleId,
      createdAt: DateTime.now(),
      familyId: familyId,
      familyRole: membershipRow?.role,
      drivingLicense: licenseRow?.toDrivingLicense(),
      ownedVehicles: vehicleRows.map((r) {
        final v = vehicleFromDrift(r);
        return FamilyVehicle(
          id: v.id,
          userId: v.userId,
          name: v.name,
          nickname: v.nickname,
          make: v.make,
          model: v.model,
          year: v.year,
          licensePlate: v.licensePlate,
          vin: v.vin,
          color: v.color,
          fuelType: v.fuelType.storage,
          mileage: v.mileage,
          mileageUnit: v.mileageUnit.name,
          purchaseDate: v.purchaseDate?.toIso8601String().split('T').first,
          purchasePrice: v.purchasePrice,
          photoMediaId: v.photoMediaId,
          archived: v.archived,
          archivedAt: v.archivedAt?.toIso8601String(),
          updatedAt: v.updatedAt,
        );
      }).toList(),
    );
  }

  Future<void> _cacheFamily(Family family) async {
    await _db
        .into(_db.familyRecords)
        .insertOnConflictUpdate(
          FamilyRecordsCompanion(
            id: drift.Value(family.id),
            name: drift.Value(family.name),
            shareCode: drift.Value(family.shareCode),
            qrCodeData: drift.Value(family.qrCodeData),
            createdBy: drift.Value(family.createdBy),
            status: drift.Value(family.status),
            createdAt: drift.Value(family.createdAt),
            archivedAt: drift.Value(family.archivedAt),
            syncedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  Future<Family?> _getCachedFamily() async {
    final rows = await _db.select(_db.familyRecords).get();
    if (rows.isEmpty) return null;
    return rows.first.toFamily();
  }

  Future<List<FamilyMember>> _getCachedMembers() async {
    final rows = await _db.select(_db.familyMembershipRecords).get();
    return rows.map((r) => r.toFamilyMember()).toList();
  }

  @override
  Future<void> clearFamilyCache() async {
    await _db.delete(_db.familyRecords).go();
    await _db.delete(_db.familyMembershipRecords).go();
    await _db.delete(_db.vehicleGrantRecords).go();
    await _db.delete(_db.drivingLicenseRecords).go();
    await _db.delete(_db.familyVehicleRecords).go();
  }

  Future<void> _cacheFamilyVehicle(FamilyVehicle fv) async {
    await _db
        .into(_db.familyVehicleRecords)
        .insertOnConflictUpdate(
          FamilyVehicleRecordsCompanion(
            id: drift.Value('fv_${fv.id}'),
            familyId: const drift.Value(''),
            vehicleId: drift.Value(fv.id),
            addedBy: drift.Value(fv.userId),
            addedAt: drift.Value(fv.createdAt ?? DateTime.now()),
            syncedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  Future<List<FamilyVehicle>> _getCachedFamilyVehicles() async {
    final rows = await _db.select(_db.familyVehicleRecords).get();
    return rows.map((r) => FamilyVehicle(
      id: r.vehicleId,
      userId: r.addedBy,
      name: '',
      make: '',
      model: '',
      year: 0,
      licensePlate: '',
      fuelType: 'petrol',
      mileage: 0,
      mileageUnit: 'mi',
      archived: false,
      updatedAt: r.addedAt,
      createdAt: r.addedAt,
      source: 'family',
    )).toList();
  }
}

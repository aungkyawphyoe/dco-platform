import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/family/data/mappers/family_mappers.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart';
import 'package:dco_mobile/features/family/domain/repositories/family_repository.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  final Dio _dio;
  final AppDatabase _db;
  final OutboxWriter _outbox;

  FamilyRepositoryImpl(this._dio, this._db, this._outbox);

  String get _baseUrl => '/v1';

  @override
  Future<Family?> getMyFamily() async {
    try {
      final response = await _dio.get('$_baseUrl/families/me');
      final family = Family.fromJson(response.data);
      await _cacheFamily(family);
      return family;
    } catch (e) {
      return _getCachedFamily();
    }
  }

  @override
  Future<Family> createFamily(String name) async {
    final response = await _dio.post('$_baseUrl/families', data: {'name': name});
    final family = Family.fromJson(response.data);
    await _cacheFamily(family);
    return family;
  }

  @override
  Future<Family> joinFamily(String code) async {
    final response = await _dio.post('$_baseUrl/families/me/join', data: {'code': code});
    final family = Family.fromJson(response.data);
    await _cacheFamily(family);
    return family;
  }

  @override
  Future<Family> updateFamily({String? name, bool regenerateShareCode = false}) async {
    final response = await _dio.patch('$_baseUrl/families/me', data: {
      if (name != null) 'name': name,
      'regenerate_share_code': regenerateShareCode,
    });
    final family = Family.fromJson(response.data);
    await _cacheFamily(family);
    return family;
  }

  @override
  Future<void> archiveFamily() async {
    await _dio.delete('$_baseUrl/families/me');
    await _clearFamilyCache();
  }

  @override
  Future<List<FamilyMember>> getMembers() async {
    try {
      final response = await _dio.get('$_baseUrl/families/me/members');
      return (response.data as List).map((e) => FamilyMember.fromJson(e)).toList();
    } catch (e) {
      return _getCachedMembers();
    }
  }

  @override
  Future<FamilyMember> updateMemberRole(String userId, String role) async {
    final response = await _dio.patch('$_baseUrl/families/me/members/$userId', data: {'role': role});
    return FamilyMember.fromJson(response.data);
  }

  @override
  Future<void> removeMember(String userId) async {
    await _dio.delete('$_baseUrl/families/me/members/$userId');
  }

  @override
  Future<VehicleGrant> grantVehicleAccess(String vehicleId, String userId, String permission) async {
    final response = await _dio.post('$_baseUrl/families/me/vehicle-grants', data: {
      'vehicle_id': vehicleId,
      'user_id': userId,
      'permission': permission,
    });
    return VehicleGrant.fromJson(response.data);
  }

  @override
  Future<void> revokeVehicleGrant(String grantId) async {
    await _dio.delete('$_baseUrl/families/me/vehicle-grants/$grantId');
  }

  @override
  Future<DrivingLicense?> getMyLicense() async {
    try {
      final response = await _dio.get('$_baseUrl/users/me/license');
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
    final response = await _dio.put('$_baseUrl/users/me/license', data: {
      'license_number': licenseNumber,
      'issuing_country': issuingCountry,
      'expiry_date': expiryDate,
      'categories': categories,
      'front_media_id': frontMediaId,
      'back_media_id': backMediaId,
    });
    return DrivingLicense.fromJson(response.data);
  }

  @override
  Future<String> uploadLicenseMedia(String side, List<int> bytes) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: 'license_$side.jpg'),
      'side': side,
    });
    final response = await _dio.post('$_baseUrl/users/me/license/media', data: formData);
    return response.data['media_id'] as String;
  }

  @override
  Future<DrivingLicense?> getMemberLicense(String userId) async {
    try {
      final response = await _dio.get('$_baseUrl/users/$userId/license');
      return DrivingLicense.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<FamilyVehicleDetail?> getVehicleDetail(String vehicleId) async {
    try {
      final response = await _dio.get('$_baseUrl/vehicles/$vehicleId/detail');
      return FamilyVehicleDetail.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserDetail?> getUserDetail(String userId) async {
    try {
      final response = await _dio.get('$_baseUrl/users/$userId/detail');
      return UserDetail.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<void> _cacheFamily(Family family) async {
    await _db.into(_db.familyRecords).insertOnConflictUpdate(
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

  Future<void> _clearFamilyCache() async {
    await _db.delete(_db.familyRecords).go();
    await _db.delete(_db.familyMembershipRecords).go();
    await _db.delete(_db.vehicleGrantRecords).go();
    await _db.delete(_db.drivingLicenseRecords).go();
  }
}

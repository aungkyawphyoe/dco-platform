import '../entities/session.dart';

abstract class ProfileRepository {
  Future<User> get();

  Future<User> update({
    required String displayName,
    String? contactPhone,
    String? address,
    String? activeVehicleId,
  });

  Future<String> uploadPhoto(String filePath);

  Future<void> deleteAccount({required String password, String? reason});

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  });

  /// Remembers an active-vehicle switch made while offline.
  Future<void> markPendingActiveVehicle({
    required String userId,
    required String vehicleId,
  });

  /// Retries a remembered switch; safe to call repeatedly.
  Future<void> flushPendingActiveVehicle(String userId);
}

import '../entities/notification.dart';

abstract class NotificationRepository {
  Stream<List<NotificationItem>> watch(String userId);

  Future<Set<String>> deliveredCycleKeys(String userId);

  Future<NotificationItem> recordDue({
    required String userId,
    required String vehicleId,
    required String planItemId,
    required String cycleKey,
    required String title,
    required String body,
    NotificationDueReason? dueReason,
  });

  Future<void> setStatus({
    required String userId,
    required String notificationId,
    required NotificationStatus status,
  });
}

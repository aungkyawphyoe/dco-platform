import '../entities/notification.dart';

abstract class NotificationRepository {
  Stream<List<NotificationItem>> watch(String userId);

  Future<void> setStatus({
    required String userId,
    required String notificationId,
    required NotificationStatus status,
  });
}

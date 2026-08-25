enum NotificationStatus {
  unread,
  read,
  done,
  dismissed;

  String get storage => name;

  static NotificationStatus parse(String? value) {
    return NotificationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => NotificationStatus.unread,
    );
  }
}

enum NotificationDueReason {
  date,
  mileage,
  both;

  String get storage => name;

  static NotificationDueReason? tryParse(String? value) {
    for (final reason in NotificationDueReason.values) {
      if (reason.name == value) return reason;
    }
    return null;
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleId,
    this.planItemId,
    this.dueReason,
  });

  final String id;
  final String userId;
  final String? vehicleId;
  final String? planItemId;
  final String title;
  final String body;
  final NotificationStatus status;
  final NotificationDueReason? dueReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status == NotificationStatus.unread || status == NotificationStatus.read;
}

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/notifications/domain/entities/notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsProvider = StreamProvider<List<NotificationItem>>((ref) {
  final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
  if (userId == null) return Stream.value(const <NotificationItem>[]);
  return ref.watch(notificationRepositoryProvider).watch(userId);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return items.where((item) => item.status == NotificationStatus.unread).length;
});

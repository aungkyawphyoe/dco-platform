import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/notifications/domain/entities/notification.dart';
import 'package:dco_mobile/features/notifications/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';

class NotificationFeedScreen extends ConsumerWidget {
  const NotificationFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.notificationsTitle)),
      body: items.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) =>
            DcoEmptyState(title: s.notificationsLoadError, body: '$error'),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.space.s5),
                child: DcoEmptyState(
                  title: s.notificationsEmptyTitle,
                  body: s.notificationsEmptyBody,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(tokens.space.s4),
            itemCount: list.length,
            separatorBuilder: (_, _) => SizedBox(height: tokens.space.s2),
            itemBuilder: (context, index) {
              final item = list[index];
              return _NotificationTile(item: item);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;

    Future<void> updateStatus(NotificationStatus status) async {
      if (userId == null) return;
      await ref
          .read(notificationRepositoryProvider)
          .setStatus(userId: userId, notificationId: item.id, status: status);
      if (status == NotificationStatus.done) {
        ref
            .read(analyticsProvider)
            .track(AnalyticsEvent.maintenanceReminderCompleted);
      } else if (status == NotificationStatus.dismissed) {
        ref
            .read(analyticsProvider)
            .track(AnalyticsEvent.maintenanceReminderDismissed);
      }
    }

    final icon = switch (item.dueReason) {
      NotificationDueReason.mileage => Icons.speed_outlined,
      NotificationDueReason.both => Icons.event_repeat_outlined,
      _ => Icons.event_outlined,
    };

    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: ListTile(
        leading: Icon(icon, color: tokens.icon.active),
        title: Text(item.title),
        subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: item.isOpen
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: s.notificationsMarkDone,
                    onPressed: () => updateStatus(NotificationStatus.done),
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: tokens.status.successFg,
                    ),
                  ),
                  IconButton(
                    tooltip: s.notificationsDismiss,
                    onPressed: () => updateStatus(NotificationStatus.dismissed),
                    icon: Icon(Icons.close, color: tokens.text.tertiary),
                  ),
                ],
              )
            : TextButton(
                onPressed: () => updateStatus(NotificationStatus.unread),
                child: Text(s.notificationsRestore),
              ),
      ),
    );
  }
}

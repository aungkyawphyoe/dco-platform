import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:flutter/material.dart';

class NotificationFeedScreen extends StatelessWidget {
  const NotificationFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const DcoEmptyState(
        title: 'No notifications',
        body: 'Due reminders will show up here.',
      ),
    );
  }
}

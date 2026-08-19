import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final session = ref.watch(sessionControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: tokens.space.s4,
        title: InkWell(
          onTap: () => context.push(AppRoutes.garage),
          child: Row(
            children: [
              Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
              SizedBox(width: tokens.space.s2),
              Text(
                'No vehicle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Icon(Icons.expand_more, color: tokens.icon.inactive),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Garage',
            onPressed: () => context.push(AppRoutes.garage),
            icon: Icon(Icons.garage_outlined, color: tokens.icon.inactive),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Icon(Icons.notifications_none, color: tokens.icon.inactive),
          ),
        ],
      ),
      body: Column(
        children: [
          if (session?.user.emailVerified == false)
            Material(
              color: tokens.status.warningBg,
              child: ListTile(
                title: Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.status.warningFg),
                ),
                trailing: TextButton(
                  onPressed: () => ref.read(sessionControllerProvider.notifier).resendVerification(),
                  child: Text('Resend', style: TextStyle(color: tokens.text.link)),
                ),
              ),
            ),
          const Expanded(child: _RegisterAction()),
        ],
      ),
    );
  }
}

class _RegisterAction extends StatelessWidget {
  const _RegisterAction();

  @override
  Widget build(BuildContext context) {
    return DcoEmptyState(
      title: 'Register a vehicle',
      body: 'Add your first car to see spend, upcoming service, and history here.',
      actionLabel: 'Register a vehicle',
      onAction: () => context.push(AppRoutes.garage),
    );
  }
}

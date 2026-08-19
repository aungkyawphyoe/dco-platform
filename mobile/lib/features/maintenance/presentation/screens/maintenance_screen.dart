import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: DcoEmptyState(
        title: active == null ? 'No active vehicle' : 'No maintenance yet',
        body: active == null
            ? 'Register a vehicle to plan service and keep history.'
            : 'Add a plan item or register a service for ${active.displayName}.',
      ),
    );
  }
}

import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PartsScreen extends ConsumerWidget {
  const PartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Parts')),
      body: DcoEmptyState(
        title: active == null ? 'No active vehicle' : 'Parts coming later',
        body: active == null
            ? 'Register a vehicle to keep a parts catalog for it.'
            : 'Parts for ${active.displayName} will be assignable when you log a service or an expense.',
      ),
    );
  }
}

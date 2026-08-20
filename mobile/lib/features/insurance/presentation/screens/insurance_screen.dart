import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Insurance')),
      body: DcoEmptyState(
        title: active == null ? 'No active vehicle' : 'Insurance coming later',
        body: active == null
            ? 'Register a vehicle to keep policies against it.'
            : 'Policies for ${active.displayName} will live here. For now, store insurance papers in Documents.',
      ),
    );
  }
}

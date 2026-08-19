import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: DcoEmptyState(
        title: active == null ? 'No active vehicle' : 'No documents yet',
        body: active == null
            ? 'Register a vehicle to store insurance, registration, and receipts.'
            : 'Upload insurance, registration, and receipts for ${active.displayName}.',
      ),
    );
  }
}

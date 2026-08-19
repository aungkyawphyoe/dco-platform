import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:flutter/material.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: const DcoEmptyState(
        title: 'No active vehicle',
        body: 'Register a vehicle to plan service and keep history.',
      ),
    );
  }
}

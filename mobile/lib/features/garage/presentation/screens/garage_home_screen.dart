import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:flutter/material.dart';

class GarageHomeScreen extends StatelessWidget {
  const GarageHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Garage')),
      body: DcoEmptyState(
        title: 'No vehicles yet',
        body: 'Register a vehicle to start tracking maintenance, documents, and spend.',
        actionLabel: 'Register a vehicle',
        onAction: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle form lands in the garage slice.')),
          );
        },
      ),
    );
  }
}

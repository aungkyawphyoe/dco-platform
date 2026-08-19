import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:flutter/material.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: const DcoEmptyState(
        title: 'No active vehicle',
        body: 'Register a vehicle to store insurance, registration, and receipts.',
      ),
    );
  }
}

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.documents),
            child: Text('Documents', style: TextStyle(color: tokens.text.link)),
          ),
        ],
      ),
      body: const DcoEmptyState(
        title: 'No active vehicle',
        body: 'Register a vehicle to log spend. Fuel here is money only — not a fuel log.',
      ),
    );
  }
}

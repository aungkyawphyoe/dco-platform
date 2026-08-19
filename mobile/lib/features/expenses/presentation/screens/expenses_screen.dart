import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final active = ref.watch(activeVehicleProvider).valueOrNull;
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
      body: DcoEmptyState(
        title: active == null ? 'No active vehicle' : 'No expenses yet',
        body: active == null
            ? 'Register a vehicle to log spend. Fuel here is money only — not a fuel log.'
            : 'Log spend for ${active.displayName}. Fuel is money only — not a fuel log.',
      ),
    );
  }
}

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/plan_item_tile.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ServiceHistoryScreen extends ConsumerWidget {
  const ServiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final history = ref.watch(maintenanceHistoryProvider);
    final lengthUnit = ref.watch(lengthUnitProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Service History')),
      body: vehicle == null
          ? const DcoEmptyState(
              title: 'No active vehicle',
              body: 'Register a vehicle to see services logged against it.',
            )
          : history.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (error, _) => DcoEmptyState(title: 'Could not load services', body: '$error'),
              data: (records) {
                if (records.isEmpty) {
                  return const DcoEmptyState(
                    title: 'No services yet',
                    body: 'Logged services for this vehicle will show up here.',
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(top: tokens.space.s3, bottom: tokens.space.s5),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return HistoryTile(
                      record: record,
                      lengthUnit: lengthUnit,
                      onTap: () => context.push(AppRoutes.serviceDetail(record.id)),
                    );
                  },
                );
              },
            ),
    );
  }
}

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/suggested_catalog.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestedItemsScreen extends ConsumerWidget {
  const SuggestedItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final plan = ref.watch(maintenancePlanProvider).valueOrNull ?? const [];
    final lengthUnit = ref.watch(lengthUnitProvider);
    final existing = plan.map((item) => item.catalogKey).whereType<String>().toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Items')),
      body: vehicle == null
          ? const DcoEmptyState(
              title: 'No active vehicle',
              body: 'Register a vehicle to add suggested items.',
            )
          : Builder(
              builder: (context) {
                final suggestions = SuggestedCatalog.forFuelType(
                  vehicle.fuelType,
                ).where((item) => !existing.contains(item.catalogKey)).toList();
                if (suggestions.isEmpty) {
                  return const DcoEmptyState(
                    title: 'All suggested items added',
                    body: 'You can still create a custom service item from the plan.',
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.all(tokens.space.s4),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: tokens.space.s3),
                      child: Material(
                        color: tokens.background.card,
                        borderRadius: BorderRadius.circular(tokens.radius.md),
                        child: Padding(
                          padding: EdgeInsets.all(tokens.space.s3),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Add ${item.name}',
                                onPressed: () async {
                                  final userId = vehicle.userId;
                                  await ref.read(maintenanceRepositoryProvider).addSuggestedItem(
                                    userId: userId,
                                    vehicle: vehicle,
                                    suggestion: item,
                                  );
                                  ref.read(analyticsProvider).track(
                                    AnalyticsEvent.maintenancePlanItemAdded,
                                    {'source': 'suggested', 'catalog_key': item.catalogKey},
                                  );
                                },
                                icon: Icon(Icons.add_circle, color: tokens.status.successFg),
                              ),
                              SizedBox(width: tokens.space.s2),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                                    SizedBox(height: tokens.space.s1),
                                    Text(
                                      DueCalculator.intervalLabel(
                                        intervalDays: item.intervalDays,
                                        intervalDistance: item.intervalDistance == null
                                            ? null
                                            : lengthUnit.toDisplay(item.intervalDistance!),
                                        unit: lengthUnit.label,
                                      ),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: tokens.text.caption,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

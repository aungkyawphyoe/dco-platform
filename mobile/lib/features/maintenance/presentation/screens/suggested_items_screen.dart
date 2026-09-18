import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestedItemsScreen extends ConsumerStatefulWidget {
  const SuggestedItemsScreen({super.key});

  @override
  ConsumerState<SuggestedItemsScreen> createState() => _SuggestedItemsScreenState();
}

class _SuggestedItemsScreenState extends ConsumerState<SuggestedItemsScreen> {
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(maintenanceCatalogRepositoryProvider).fetchAndCache(vehicle.id);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final plan = ref.watch(maintenancePlanProvider).valueOrNull ?? const [];
    final lengthUnit = ref.watch(lengthUnitProvider);
    final existing = plan.map((item) => item.catalogKey).whereType<String>().toSet();
    final suggestionsAsync = ref.watch(suggestedItemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.suggestedItemsTitle)),
      body: vehicle == null
          ? DcoEmptyState(
              title: s.maintenanceNoActiveVehicle,
              body: s.suggestedItemsNoActiveVehicleBody,
            )
          : suggestionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => DcoEmptyState(
                title: 'Unable to load suggestions',
                body: 'Pull to retry.',
              ),
              data: (suggestions) {
                final filtered = suggestions
                    .where((item) => !existing.contains(item.catalogKey))
                    .toList();
                if (filtered.isEmpty) {
                  return DcoEmptyState(
                    title: s.suggestedItemsAllAdded,
                    body: s.suggestedItemsAllAddedBody,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    padding: EdgeInsets.all(tokens.space.s4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
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
                                  tooltip: s.suggestedItemAdd(item.name),
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
                  ),
                );
              },
            ),
    );
  }
}

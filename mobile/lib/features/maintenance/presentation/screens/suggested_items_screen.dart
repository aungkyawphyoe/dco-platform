import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'plan_item_form_screen.dart';

class SuggestedItemsScreen extends ConsumerWidget {
  const SuggestedItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final vehicle = ref.watch(activeVehicleProvider).asData?.value;
    final userId = ref.watch(currentUserIdProvider);
    final scope = (userId: userId ?? '', vehicleId: vehicle?.id ?? '');
    final suggestions = ref.watch(suggestedItemsProvider(scope));
    final plan = ref.watch(suggestedVehiclePlanProvider(scope));
    final refresh = ref.watch(maintenanceCatalogRefreshProvider);

    Future<void> retry() async {
      ref.invalidate(maintenanceCatalogRefreshProvider);
      try {
        await ref.read(maintenanceCatalogRefreshProvider.future);
      } catch (_) {
        // The refresh provider retains the error and the offline cache.
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.suggestedItemsTitle)),
      body: suggestions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: TextButton(onPressed: retry, child: Text(s.retry)),
        ),
        data: (items) {
          if (items == null && refresh.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items == null || items.isEmpty) {
            return RefreshIndicator(
              onRefresh: retry,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  DcoEmptyState(
                    title: items == null
                        ? s.suggestedItemsUnavailable
                        : s.suggestedItemsNoneAvailable,
                    body: items == null
                        ? s.suggestedItemsRetryBody
                        : s.suggestedItemsNoneAvailableBody,
                  ),
                  Center(
                    child: TextButton(onPressed: retry, child: Text(s.retry)),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: retry,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.tokens.space.s4),
              children: [
                for (final item in items)
                  Builder(
                    builder: (context) {
                      final existing = plan.asData?.value
                          .where(
                            (entry) =>
                                entry.enabled &&
                                entry.catalogKey == item.catalogKey,
                          )
                          .firstOrNull;
                      final VoidCallback? setup =
                          plan.asData == null || vehicle == null
                          ? null
                          : () {
                              showPlanItemForm(
                                context,
                                planItemId: existing?.id,
                                initialName: item.name,
                                catalogKey: item.catalogKey,
                              );
                            };
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: context.tokens.space.s2,
                        ),
                        child: DcoCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: context.tokens.space.s4,
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(item.name)),
                                if (existing != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: context.tokens.space.s2,
                                    ),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: context.tokens.status.successFg,
                                      size: 20,
                                      semanticLabel:
                                          s.suggestedItemsAlreadySetUp,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: TextButton(
                              onPressed: setup,
                              child: Text(s.suggestedItemsSetUp),
                            ),
                            onTap: setup,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

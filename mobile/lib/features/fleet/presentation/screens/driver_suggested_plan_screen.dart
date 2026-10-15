import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// Driver mode: add items from the assigned maintenance template set to the
/// vehicle's plan. Multi-select; each add is idempotent by a client UUID.
class DriverSuggestedPlanScreen extends ConsumerStatefulWidget {
  const DriverSuggestedPlanScreen({super.key});

  @override
  ConsumerState<DriverSuggestedPlanScreen> createState() =>
      _DriverSuggestedPlanScreenState();
}

class _DriverSuggestedPlanScreenState
    extends ConsumerState<DriverSuggestedPlanScreen> {
  final _selected = <String>{};
  bool _saving = false;

  Future<void> _addSelected(
    String vehicleId,
    List<DriverSuggestedPlanItem> items,
  ) async {
    final s = AppLocalizations.of(context)!;
    final picked = items.where(
      (item) => _selected.contains(item.catalogKey) && item.hasInterval,
    );
    if (picked.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(fleetRepositoryProvider);
      const uuid = Uuid();
      for (final item in picked) {
        await repository.addDriverPlanItem(
          vehicleId,
          id: uuid.v4(),
          name: item.name,
          intervalDays: item.intervalDays,
          intervalDistance: item.intervalDistance,
        );
      }
      ref.invalidate(driverPlanItemsProvider(vehicleId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.driverPlanItemAdded)));
      context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final myVehicleAsync = ref.watch(driverMyVehicleProvider);

    return Scaffold(
      backgroundColor: tokens.background.primary,
      appBar: AppBar(title: Text(s.driverSuggestedTitle)),
      body: myVehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(driverMyVehicleProvider),
        ),
        data: (ctx) {
          if (!ctx.hasAssignedVehicle) {
            return DcoEmptyState(
              title: s.driverNoVehicleTitle,
              body: s.driverNoVehicleBody,
            );
          }
          final vehicleId = ctx.vehicle!.id;
          final suggestedAsync = ref.watch(
            driverSuggestedPlanItemsProvider(vehicleId),
          );

          return suggestedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(
                driverSuggestedPlanItemsProvider(vehicleId),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return DcoEmptyState(
                  title: s.driverSuggestedEmpty,
                  body: s.driverSuggestedEmptyBody,
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(tokens.space.s3),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selectable = item.hasInterval;
                        return Card(
                          margin: EdgeInsets.only(bottom: tokens.space.s2),
                          child: CheckboxListTile(
                            enabled: selectable && !_saving,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _selected.contains(item.catalogKey),
                            onChanged: selectable && !_saving
                                ? (checked) => setState(() {
                                      if (checked == true) {
                                        _selected.add(item.catalogKey);
                                      } else {
                                        _selected.remove(item.catalogKey);
                                      }
                                    })
                                : null,
                            title: Text(item.name),
                            subtitle: Text(
                              selectable
                                  ? _intervalSummary(item)
                                  : s.driverSuggestedNoInterval,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.text.caption),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        tokens.space.s3,
                        tokens.space.s2,
                        tokens.space.s3,
                        tokens.space.s3,
                      ),
                      child: DcoButton(
                        label: s.driverSuggestedAdd,
                        loading: _saving,
                        onPressed: _selected.isEmpty || _saving
                            ? null
                            : () => _addSelected(vehicleId, items),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _intervalSummary(DriverSuggestedPlanItem item) {
    return [
      if (item.intervalDays != null) '${item.intervalDays}d',
      if (item.intervalDistance != null)
        '${item.intervalDistance!.round()} km',
    ].join(' · ');
  }
}

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/suggested_plan_item.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestedItemsScreen extends ConsumerStatefulWidget {
  const SuggestedItemsScreen({super.key});

  @override
  ConsumerState<SuggestedItemsScreen> createState() =>
      _SuggestedItemsScreenState();
}

class _SuggestedItemsScreenState extends ConsumerState<SuggestedItemsScreen> {
  bool _isRefreshing = false;
  final Set<String> _selectedCatalogKeys = {};

  Future<void> _onRefresh() async {
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    setState(() => _isRefreshing = true);
    try {
      await ref
          .read(maintenanceCatalogRepositoryProvider)
          .fetchAndCache(vehicle.id);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _toggleSelection(String catalogKey) {
    setState(() {
      if (_selectedCatalogKeys.contains(catalogKey)) {
        _selectedCatalogKeys.remove(catalogKey);
      } else {
        _selectedCatalogKeys.add(catalogKey);
      }
    });
  }

  void _selectAll(List<SuggestedPlanItem> items) {
    setState(() {
      if (_selectedCatalogKeys.length == items.length) {
        _selectedCatalogKeys.clear();
      } else {
        _selectedCatalogKeys.addAll(items.map((e) => e.catalogKey));
      }
    });
  }

  Future<void> _showTrackingStartDialog(
    BuildContext context,
    List<SuggestedPlanItem> selectedItems,
    Vehicle vehicle,
  ) async {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    DateTime selectedDate = DateTime.now();
    final mileageController = TextEditingController(
      text: vehicle.mileage.toStringAsFixed(1),
    );
    double? conditionFraction;
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.background.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radius.xl),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: tokens.space.s4,
            right: tokens.space.s4,
            top: tokens.space.s4,
            bottom: MediaQuery.of(context).viewInsets.bottom + tokens.space.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.suggestedItemsTrackingStartTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tokens.text.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: tokens.space.s2),
              Text(
                s.suggestedItemsTrackingStartBody(selectedItems.length),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
              ),
              SizedBox(height: tokens.space.s4),
              _TrackingStartField(
                label: s.suggestedItemsStartDate,
                value: selectedDate,
                onChanged: (date) => setModalState(() => selectedDate = date),
              ),
              SizedBox(height: tokens.space.s3),
              _TrackingStartField(
                label: s.suggestedItemsStartMileage,
                controller: mileageController,
                keyboardType: TextInputType.number,
                unit: s.lengthUnitKm,
              ),
              SizedBox(height: tokens.space.s4),
              _ConditionSelector(
                initialValue: conditionFraction,
                onChanged: (value) =>
                    setModalState(() => conditionFraction = value),
                tokens: tokens,
              ),
              SizedBox(height: tokens.space.s4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: tokens.space.s3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            tokens.radius.full,
                          ),
                        ),
                        side: BorderSide(color: tokens.border.subtle),
                      ),
                      child: Text(s.cancel),
                    ),
                  ),
                  SizedBox(width: tokens.space.s3),
                  Expanded(
                    child: FilledButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final mileage = double.tryParse(
                                mileageController.text.replaceAll(',', ''),
                              );
                              if (mileage == null) return;

                              setModalState(() => isLoading = true);
                              try {
                                await ref
                                    .read(maintenanceRepositoryProvider)
                                    .addSuggestedItems(
                                      userId: vehicle.userId,
                                      vehicle: vehicle,
                                      suggestions: selectedItems,
                                      trackingStartDate: selectedDate,
                                      trackingStartMileage: mileage,
                                      conditionFraction: conditionFraction,
                                    );
                                ref.read(analyticsProvider).track(
                                  AnalyticsEvent.maintenancePlanItemAdded,
                                  {
                                    'source': 'suggested_batch',
                                    'count': selectedItems.length,
                                    'condition_fraction': conditionFraction,
                                  },
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  setState(() => _selectedCatalogKeys.clear());
                                }
                              } finally {
                                if (mounted)
                                  setModalState(() => isLoading = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: tokens.space.s3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            tokens.radius.full,
                          ),
                        ),
                        backgroundColor: tokens.button.primary.background,
                        foregroundColor: tokens.text.onAccent,
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.text.onAccent,
                              ),
                            )
                          : Text(s.add),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.space.s2),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final plan = ref.watch(maintenancePlanProvider).valueOrNull ?? const [];
    final lengthUnit = ref.watch(lengthUnitProvider);
    final existing = plan
        .map((item) => item.catalogKey)
        .whereType<String>()
        .toSet();
    final suggestionsAsync = ref.watch(suggestedItemsProvider);

    final selectedCount = _selectedCatalogKeys.length;
    final showFab = selectedCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.suggestedItemsTitle),
        actions: [
          if (showFab)
            Padding(
              padding: EdgeInsets.only(right: tokens.space.s2),
              child: Center(
                child: Text(
                  '$selectedCount ${s.suggestedItemsSelected}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tokens.text.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              heroTag: 'fab-add-suggested',
              backgroundColor: tokens.button.primary.background,
              foregroundColor: tokens.text.onAccent,
              onPressed: () {
                final suggestions = suggestionsAsync.valueOrNull ?? [];
                final selectedItems = suggestions
                    .where(
                      (item) => _selectedCatalogKeys.contains(item.catalogKey),
                    )
                    .toList();
                if (selectedItems.isNotEmpty && vehicle != null) {
                  _showTrackingStartDialog(context, selectedItems, vehicle);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(s.add),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radius.full),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                    padding: EdgeInsets.fromLTRB(
                      tokens.space.s4,
                      tokens.space.s3,
                      tokens.space.s4,
                      tokens.space.s5 + 80, // Space for FAB
                    ),
                    itemCount: filtered.length + 1, // +1 for select all header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Select all header
                        return _SelectAllHeader(
                          selectedCount: selectedCount,
                          totalCount: filtered.length,
                          onTap: () => _selectAll(filtered),
                          tokens: tokens,
                        );
                      }
                      final item = filtered[index - 1];
                      final isSelected = _selectedCatalogKeys.contains(
                        item.catalogKey,
                      );
                      return Padding(
                        padding: EdgeInsets.only(bottom: tokens.space.s3),
                        child: Material(
                          color: isSelected
                              ? tokens.status.successFg.withValues(alpha: 0.1)
                              : tokens.background.card,
                          borderRadius: BorderRadius.circular(tokens.radius.md),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              tokens.radius.md,
                            ),
                            onTap: () => _toggleSelection(item.catalogKey),
                            child: Padding(
                              padding: EdgeInsets.all(tokens.space.s3),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) =>
                                        _toggleSelection(item.catalogKey),
                                    activeColor: tokens.status.successFg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        tokens.radius.sm,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: tokens.space.s2),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: isSelected
                                                    ? tokens.text.primary
                                                    : tokens.text.primary,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                        ),
                                        SizedBox(height: tokens.space.s1),
                                        Text(
                                          DueCalculator.intervalLabel(
                                            intervalDays: item.intervalDays,
                                            intervalDistance:
                                                item.intervalDistance == null
                                                ? null
                                                : lengthUnit.toDisplay(
                                                    item.intervalDistance!,
                                                  ),
                                            unit: lengthUnit.label,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: tokens.text.caption,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.add_circle_outline,
                                    color: isSelected
                                        ? tokens.status.successFg
                                        : tokens.icon.inactive,
                                  ),
                                ],
                              ),
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

class _SelectAllHeader extends StatelessWidget {
  const _SelectAllHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.onTap,
    required this.tokens,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onTap;
  final DcoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final isAllSelected = selectedCount == totalCount && totalCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: Padding(
        padding: EdgeInsets.all(tokens.space.s3),
        child: Row(
          children: [
            Checkbox(
              value: isAllSelected,
              onChanged: (_) => onTap(),
              activeColor: tokens.status.successFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radius.sm),
              ),
            ),
            SizedBox(width: tokens.space.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select all ($totalCount)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (selectedCount > 0)
                    Text(
                      '$selectedCount of $totalCount selected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.tokens.text.caption,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isAllSelected ? Icons.check_circle : Icons.add_circle_outline,
              color: isAllSelected
                  ? tokens.status.successFg
                  : tokens.icon.inactive,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingStartField extends StatelessWidget {
  const _TrackingStartField({
    required this.label,
    this.value,
    this.onChanged,
    this.controller,
    this.keyboardType,
    this.unit,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: tokens.text.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: tokens.space.s2),
        if (value != null && onChanged != null)
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value!,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) onChanged!(picked);
            },
            child: Container(
              padding: EdgeInsets.all(tokens.space.s3),
              decoration: BoxDecoration(
                color: tokens.background.input,
                borderRadius: BorderRadius.circular(tokens.radius.md),
                border: Border.all(color: tokens.border.subtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: tokens.icon.active,
                    size: 20,
                  ),
                  SizedBox(width: tokens.space.s3),
                  Text(
                    '${value!.day}/${value!.month}/${value!.year}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: tokens.text.primary),
                  ),
                ],
              ),
            ),
          )
        else if (controller != null)
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: 'e.g. 15000',
              suffixText: unit,
              filled: true,
              fillColor: tokens.background.input,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radius.md),
                borderSide: BorderSide(color: tokens.border.subtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radius.md),
                borderSide: BorderSide(color: tokens.border.subtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radius.md),
                borderSide: BorderSide(
                  color: tokens.button.primary.background,
                  width: 2,
                ),
              ),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.text.primary),
          ),
      ],
    );
  }
}

class _ConditionSelector extends StatelessWidget {
  const _ConditionSelector({
    required this.initialValue,
    required this.onChanged,
    required this.tokens,
  });

  final double? initialValue;
  final ValueChanged<double?> onChanged;
  final DcoTokens tokens;

  static const _options = [
    (
      value: null,
      label: 'New parts (full interval)',
      description: 'For brand new components',
    ),
    (value: 0.5, label: 'Half interval (50%)', description: 'Parts ~50% worn'),
    (
      value: 0.33,
      label: 'Third interval (33%)',
      description: 'Parts ~67% worn',
    ),
    (
      value: 0.25,
      label: 'Quarter interval (25%)',
      description: 'Parts ~75% worn',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condition (for used cars)',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: tokens.text.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: tokens.space.s2),
        Text(
          'If the car is used, the previous owner may have done some maintenance. Start tracking from a fraction of the interval.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
        ),
        SizedBox(height: tokens.space.s2),
        Wrap(
          spacing: tokens.space.s2,
          runSpacing: tokens.space.s2,
          children: _options.map((option) {
            final isSelected = initialValue == option.value;
            return ChoiceChip(
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? tokens.text.onAccent
                          : tokens.text.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    option.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? tokens.text.onAccent.withValues(alpha: 0.8)
                          : tokens.text.caption,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(option.value),
              selectedColor: tokens.button.primary.background,
              backgroundColor: tokens.background.input,
              side: BorderSide(
                color: isSelected
                    ? tokens.button.primary.background
                    : tokens.border.subtle,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radius.full),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.s3,
                vertical: tokens.space.s2,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FuelLogsScreen extends ConsumerStatefulWidget {
  const FuelLogsScreen({super.key});

  @override
  ConsumerState<FuelLogsScreen> createState() => _FuelLogsScreenState();
}

class _FuelLogsScreenState extends ConsumerState<FuelLogsScreen> {
  String? _fuelTypeId;
  _LogPeriod _period = _LogPeriod.all;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final kind = ref.watch(vehicleFuelLogKindProvider);
    final logs = ref.watch(vehicleFuelLogsProvider);
    final types = ref.watch(matchingFuelTypesProvider);
    final currency = ref.watch(userPreferencesProvider).valueOrNull?.currency.code ?? 'USD';
    final title = kind?.label ?? 'Refuel';
    ref.watch(seedFuelTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Fuel Types',
            onPressed: vehicle == null ? null : () => context.push(AppRoutes.fuelTypes),
            icon: Icon(
              Icons.local_gas_station_outlined,
              color: vehicle == null ? tokens.icon.inactive : tokens.icon.active,
            ),
          ),
          IconButton(
            tooltip: kind == FuelLogKind.charge ? 'Add a charge' : 'Add a refill',
            onPressed: vehicle == null ? null : () => context.push(AppRoutes.fuelLogNew),
            icon: Icon(Icons.add, color: vehicle == null ? tokens.icon.inactive : tokens.icon.active),
          ),
        ],
      ),
      body: vehicle == null || kind == null
          ? const DcoEmptyState(
              title: 'No active vehicle',
              body: 'Register a vehicle to log fuel or charging.',
            )
          : logs.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (error, _) => DcoEmptyState(title: 'Could not load $title', body: '$error'),
              data: (items) {
                final filtered = _applyFilters(items);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilterBar(
                      types: types,
                      selectedTypeId: _fuelTypeId,
                      period: _period,
                      onTypeSelected: (id) => setState(() => _fuelTypeId = id),
                      onPeriodSelected: (period) => setState(() => _period = period),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? DcoEmptyState(
                              title: kind == FuelLogKind.charge ? 'No charges yet' : 'No refuels yet',
                              body: kind == FuelLogKind.charge
                                  ? 'Log charging for ${vehicle.displayName}.'
                                  : 'Log a refill for ${vehicle.displayName}.',
                              actionLabel: kind.addLabel,
                              onAction: () => context.push(AppRoutes.fuelLogNew),
                            )
                          : filtered.isEmpty
                          ? DcoEmptyState(
                              title: 'No matching logs',
                              body: 'Try a different fuel type or date filter.',
                            )
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                tokens.space.s4,
                                tokens.space.s2,
                                tokens.space.s4,
                                tokens.space.s5,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final log = filtered[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: tokens.space.s3),
                                  child: _FuelLogTile(
                                    log: log,
                                    currency: currency,
                                    onTap: () => context.push(AppRoutes.fuelLogEdit(log.id)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  List<FuelLog> _applyFilters(List<FuelLog> items) {
    final now = DateTime.now();
    return items.where((log) {
      if (_fuelTypeId != null && log.fuelTypeId != _fuelTypeId) return false;
      if (_period == _LogPeriod.thisMonth) {
        return log.loggedOn.year == now.year && log.loggedOn.month == now.month;
      }
      return true;
    }).toList();
  }
}

enum _LogPeriod { all, thisMonth }

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.types,
    required this.selectedTypeId,
    required this.period,
    required this.onTypeSelected,
    required this.onPeriodSelected,
  });

  final List<FuelCatalogType> types;
  final String? selectedTypeId;
  final _LogPeriod period;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<_LogPeriod> onPeriodSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, tokens.space.s3, tokens.space.s4, tokens.space.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All types',
                  selected: selectedTypeId == null,
                  onTap: () => onTypeSelected(null),
                ),
                for (final type in types) ...[
                  SizedBox(width: tokens.space.s2),
                  _FilterChip(
                    label: type.name,
                    selected: selectedTypeId == type.id,
                    onTap: () => onTypeSelected(type.id),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: tokens.space.s2),
          Row(
            children: [
              _FilterChip(
                label: 'All dates',
                selected: period == _LogPeriod.all,
                onTap: () => onPeriodSelected(_LogPeriod.all),
              ),
              SizedBox(width: tokens.space.s2),
              _FilterChip(
                label: 'This month',
                selected: period == _LogPeriod.thisMonth,
                onTap: () => onPeriodSelected(_LogPeriod.thisMonth),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.text.accent : tokens.background.input,
      borderRadius: BorderRadius.circular(tokens.radius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space.s3),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? tokens.text.onAccent : tokens.text.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FuelLogTile extends StatelessWidget {
  const _FuelLogTile({
    required this.log,
    required this.currency,
    required this.onTap,
  });

  final FuelLog log;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isCharge = log.kind == FuelLogKind.charge;
    final color = tokens.chart.fuel;
    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Icon(
                  isCharge ? Icons.bolt_outlined : Icons.local_gas_station_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(log.loggedOn),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                    ),
                    SizedBox(height: tokens.space.s1),
                    Text(log.fuelTypeName, style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: tokens.space.s1),
                    Text(
                      log.amountLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                    ),
                  ],
                ),
              ),
              Text(
                '${log.cost.toStringAsFixed(2)} $currency',
                style: GoogleFonts.ibmPlexMono(color: tokens.text.secondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

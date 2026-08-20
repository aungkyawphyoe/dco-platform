import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FuelTypesScreen extends ConsumerStatefulWidget {
  const FuelTypesScreen({super.key});

  @override
  ConsumerState<FuelTypesScreen> createState() => _FuelTypesScreenState();
}

class _FuelTypesScreenState extends ConsumerState<FuelTypesScreen> {
  FuelCatalogKind? _kind;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final catalog = ref.watch(fuelCatalogProvider);
    ref.watch(seedFuelTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Types'),
        actions: [
          IconButton(
            tooltip: 'Add a fuel type',
            onPressed: vehicle == null ? null : () => context.push(AppRoutes.fuelTypeNew),
            icon: Icon(Icons.add, color: vehicle == null ? tokens.icon.inactive : tokens.icon.active),
          ),
        ],
      ),
      body: vehicle == null
          ? const DcoEmptyState(
              title: 'No active vehicle',
              body: 'Register a vehicle to keep a fuel type catalog.',
            )
          : catalog.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (error, _) => DcoEmptyState(title: 'Could not load fuel types', body: '$error'),
              data: (items) {
                final filtered = _kind == null ? items : items.where((item) => item.kind == _kind).toList();
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        tokens.space.s4,
                        tokens.space.s3,
                        tokens.space.s4,
                        tokens.space.s2,
                      ),
                      child: Row(
                        children: [
                          _KindChip(label: 'All', selected: _kind == null, onTap: () => setState(() => _kind = null)),
                          SizedBox(width: tokens.space.s2),
                          _KindChip(
                            label: 'Liquid',
                            selected: _kind == FuelCatalogKind.liquid,
                            onTap: () => setState(() => _kind = FuelCatalogKind.liquid),
                          ),
                          SizedBox(width: tokens.space.s2),
                          _KindChip(
                            label: 'Electric',
                            selected: _kind == FuelCatalogKind.electric,
                            onTap: () => setState(() => _kind = FuelCatalogKind.electric),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? DcoEmptyState(
                              title: 'No fuel types yet',
                              body: 'Add petrol, diesel, electricity, or your own names.',
                              actionLabel: 'Add fuel type',
                              onAction: () => context.push(AppRoutes.fuelTypeNew),
                            )
                          : filtered.isEmpty
                          ? const DcoEmptyState(
                              title: 'No matching types',
                              body: 'Try a different filter or add a type.',
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
                                final type = filtered[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: tokens.space.s3),
                                  child: _FuelTypeTile(
                                    type: type,
                                    onTap: () => context.push(AppRoutes.fuelTypeEdit(type.id)),
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
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.selected, required this.onTap});

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

class _FuelTypeTile extends StatelessWidget {
  const _FuelTypeTile({required this.type, required this.onTap});

  final FuelCatalogType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final electric = type.kind == FuelCatalogKind.electric;
    final color = electric ? tokens.status.infoFg : tokens.chart.fuel;
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
                  electric ? Icons.bolt_outlined : Icons.local_gas_station_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name, style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: tokens.space.s1),
                    Text(
                      type.detailLine,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.icon.inactive),
            ],
          ),
        ),
      ),
    );
  }
}

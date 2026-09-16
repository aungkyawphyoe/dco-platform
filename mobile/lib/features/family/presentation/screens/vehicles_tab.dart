import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart' as family_entities;
import 'package:dco_mobile/features/family/presentation/providers/family_vehicle_providers.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/presentation/widgets/vehicle_card.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VehiclesTab extends ConsumerWidget {
  const VehiclesTab({super.key, required this.family});

  final family_entities.Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final vehiclesAsync = ref.watch(familyVehiclesProvider);

    final isOwner = family.myRole == 'primary_owner';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: context.tokens.text.accent),
              const SizedBox(width: 8),
              Text(
                s.vehiclesTabTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isOwner)
                FilledButton.icon(
                  onPressed: () => _showAddVehicleDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.vehiclesTabAdd),
                ),
            ],
          ),
        ),
        Expanded(
          child: vehiclesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 64,
                        color: context.tokens.text.tertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.vehiclesTabEmptyTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.tokens.text.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOwner
                            ? s.vehiclesTabEmptyBodyOwner
                            : s.vehiclesTabEmptyBodyNonOwner,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.tokens.text.tertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: VehicleCard(
                      vehicle: vehicle.toVehicle(),
                      isActive: false,
                      isFamily: true,
                      onOpen: () {
                        // Navigate to vehicle detail
                      },
                      onDelete: isOwner
                          ? () => _confirmRemove(context, ref, vehicle)
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddVehicleDialog(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final garageAsync = ref.read(garageVehiclesProvider);
    final familyAsync = ref.read(familyVehiclesProvider);

    final myVehicles = garageAsync.valueOrNull ?? [];
    final familyVehicleIds = (familyAsync.valueOrNull ?? []).map((v) => v.id).toSet();
    final available = myVehicles.where((v) => !familyVehicleIds.contains(v.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.vehiclesTabNoVehiclesToAdd)),
      );
      return;
    }

    final selected = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 2 / 3,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: tokens.text.tertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                s.vehiclesTabSelectTitle,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.vehiclesTabSelectSubtitle,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: tokens.text.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (_, index) {
                    final vehicle = available[index];
                    final isSelected = selected.contains(vehicle.id);
                    return _VehicleSelectTile(
                      vehicle: vehicle,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selected.remove(vehicle.id);
                          } else {
                            selected.add(vehicle.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final actions = ref.read(familyActionsProvider);
                          for (final vehicleId in selected) {
                            await actions.addVehicleToFamily(vehicleId);
                          }
                          ref.invalidate(familyVehiclesProvider);
                        },
                  child: Text(
                    s.vehiclesTabAddSelected(selected.length),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, family_entities.FamilyVehicle vehicle) {
    final s = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.vehiclesTabRemoveTitle),
        content: Text(s.vehiclesTabRemoveBody(vehicle.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(familyActionsProvider).removeVehicleFromFamily(vehicle.id);
            },
            child: Text(s.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _VehicleSelectTile extends StatelessWidget {
  const _VehicleSelectTile({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: isSelected ? tokens.text.accent.withValues(alpha: 0.1) : tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s3),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: tokens.text.accent,
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      vehicle.yearMakeModel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.secondary,
                      ),
                    ),
                    Text(
                      vehicle.licensePlate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.tertiary,
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
  }
}

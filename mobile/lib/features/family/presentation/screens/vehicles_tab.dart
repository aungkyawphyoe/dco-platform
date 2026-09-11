import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart' as family_entities;
import 'package:dco_mobile/features/family/presentation/providers/family_vehicle_providers.dart';
import 'package:dco_mobile/features/garage/presentation/widgets/vehicle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VehiclesTab extends ConsumerWidget {
  const VehiclesTab({super.key, required this.family});

  final family_entities.Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(familyVehiclesProvider);

    final isOwner = family.myRole == 'owner';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: context.tokens.text.accent),
              const SizedBox(width: 8),
              Text(
                'Family Vehicles',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isOwner)
                FilledButton.icon(
                  onPressed: () => _showAddVehicleDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
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
                        'No vehicles in family',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.tokens.text.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOwner
                            ? 'Tap "Add" to share a vehicle with your family'
                            : 'Ask the owner to share a vehicle',
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
    // TODO: Implement add vehicle dialog
    // This would show a list of user's vehicles to select from
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a vehicle to share'),
            SizedBox(height: 16),
            Text('TODO: Vehicle list'),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, family_entities.FamilyVehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Vehicle'),
        content: Text('Remove ${vehicle.displayName} from family?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(familyActionsProvider).removeVehicleFromFamily(vehicle.id);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

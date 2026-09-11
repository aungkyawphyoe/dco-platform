import 'package:flutter/material.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart'
    as family_entities;
import 'package:dco_mobile/features/family/presentation/widgets/family_empty_state.dart';

class VehiclesTab extends StatelessWidget {
  final family_entities.Family family;

  const VehiclesTab({super.key, required this.family});

  @override
  Widget build(BuildContext context) {
    return const FamilyEmptyState(
      icon: Icons.directions_car_outlined,
      title: 'No vehicles in family',
      message: 'Vehicles will appear here when members add them.',
    );
  }
}

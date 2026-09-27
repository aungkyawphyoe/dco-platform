import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/fleet_vehicle_list.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Org Management → Vehicles tab.
class OrgVehiclesTab extends StatelessWidget {
  const OrgVehiclesTab({super.key, required this.orgId, required this.canAdd});

  final String orgId;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canAdd
          ? FloatingActionButton(
              heroTag: 'btn-fleet-add-inventory-org',
              tooltip: s.fleetInventoryAdd,
              onPressed: () => context.push(AppRoutes.fleetVehicleNew),
              child: const Icon(Icons.add),
            )
          : null,
      body: FleetVehicleList(
        orgId: orgId,
        onAdd: canAdd ? () => context.push(AppRoutes.fleetVehicleNew) : null,
      ),
    );
  }
}

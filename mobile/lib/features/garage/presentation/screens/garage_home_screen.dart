import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/presentation/widgets/vehicle_card.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GarageHomeScreen extends ConsumerWidget {
  const GarageHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final vehicles = ref.watch(garageVehiclesProvider);
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
    final lengthUnit = ref.watch(lengthUnitProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Garage'),
        actions: [
          IconButton(
            tooltip: 'Register a vehicle',
            onPressed: () => context.push(AppRoutes.vehicleNew),
            icon: Icon(Icons.add, color: tokens.icon.active),
          ),
        ],
      ),
      body: vehicles.when(
        loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) => DcoEmptyState(title: 'Could not load garage', body: '$error'),
        data: (items) {
          if (items.isEmpty) {
            return DcoEmptyState(
              title: 'No vehicles yet',
              body: 'Register a vehicle to start tracking maintenance, documents, and spend.',
              actionLabel: 'Register a vehicle',
              onAction: () => context.push(AppRoutes.vehicleNew),
            );
          }
          return ListView(
            padding: EdgeInsets.all(tokens.space.s4),
            children: [
              ...items.map(
                (vehicle) => Padding(
                  padding: EdgeInsets.only(bottom: tokens.space.s3),
                  child: VehicleCard(
                    vehicle: vehicle,
                    isActive: vehicle.id == active?.id,
                    lengthUnit: lengthUnit,
                    onOpen: () => context.push(AppRoutes.vehicleEdit(vehicle.id)),
                    onSetActive: vehicle.id == active?.id || userId == null
                        ? null
                        : () async {
                            await ref.read(vehicleRepositoryProvider).setActive(
                              userId: userId,
                              vehicleId: vehicle.id,
                            );
                            ref.read(analyticsProvider).track(AnalyticsEvent.vehicleSwitched);
                            if (context.mounted) context.go(AppRoutes.dashboard);
                          },
                  ),
                ),
              ),
              SizedBox(height: tokens.space.s3),
              Material(
                color: tokens.background.card,
                borderRadius: BorderRadius.circular(tokens.radius.md),
                child: InkWell(
                  onTap: () => context.push(AppRoutes.vehicleNew),
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                  child: Padding(
                    padding: EdgeInsets.all(tokens.space.s4),
                    child: Column(
                      children: [
                        Text(
                          '+ Register Another Vehicle',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tokens.text.accent),
                        ),
                        SizedBox(height: tokens.space.s2),
                        Text(
                          'Track maintenance, expenses & documents',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

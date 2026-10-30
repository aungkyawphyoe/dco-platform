import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../../features/garage/domain/entities/vehicle.dart';
import '../../features/garage/providers.dart';
import '../../features/garage/presentation/screens/garage_home_screen.dart';
import '../../features/vehicle_sharing/presentation/screens/shared_vehicles_screen.dart';
import '../../generated/app_localizations.dart';

/// Route-level composition keeps the two feature screens independent.
class GarageOverviewScreen extends ConsumerWidget {
  const GarageOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personal = ref.watch(driverOrganizationIdProvider) == null;
    final vehicles =
        ref.watch(garageVehiclesProvider).valueOrNull ?? const <Vehicle>[];
    final hasShared =
        personal && vehicles.any((v) => v.source == VehicleSource.shared);
    if (!hasShared) return const GarageHomeScreen();
    final s = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.garageMyGarage),
          bottom: TabBar(
            tabs: [
              Tab(text: s.garageOwnedTab),
              Tab(text: s.garageSharedBadge),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GarageHomeScreen(embedded: true),
            SharedVehiclesScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}

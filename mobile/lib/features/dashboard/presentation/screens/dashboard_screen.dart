import 'dart:io';

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final active = ref.watch(activeVehicleProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: tokens.space.s4,
        title: InkWell(
          onTap: () => context.push(AppRoutes.garage),
          child: Row(
            children: [
              Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
              SizedBox(width: tokens.space.s2),
              Flexible(
                child: Text(
                  active.valueOrNull?.displayName ?? 'No vehicle',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.expand_more, color: tokens.icon.inactive),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Garage',
            onPressed: () => context.push(AppRoutes.garage),
            icon: Icon(Icons.garage_outlined, color: tokens.icon.inactive),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Icon(Icons.notifications_none, color: tokens.icon.inactive),
          ),
        ],
      ),
      body: Column(
        children: [
          if (session?.user.emailVerified == false)
            Material(
              color: tokens.status.warningBg,
              child: ListTile(
                title: Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.status.warningFg),
                ),
                trailing: TextButton(
                  onPressed: () => ref.read(sessionControllerProvider.notifier).resendVerification(),
                  child: Text('Resend', style: TextStyle(color: tokens.text.link)),
                ),
              ),
            ),
          Expanded(
            child: active.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (error, _) => DcoEmptyState(title: 'Could not load dashboard', body: '$error'),
              data: (vehicle) {
                if (vehicle == null) {
                  return DcoEmptyState(
                    title: 'Register a vehicle',
                    body: 'Add your first car to see spend, upcoming service, and history here.',
                    actionLabel: 'Register a vehicle',
                    actionKey: const Key('register-vehicle-cta'),
                    onAction: () => context.push(AppRoutes.vehicleNew),
                  );
                }
                return _PopulatedDashboard(vehicle: vehicle);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PopulatedDashboard extends StatelessWidget {
  const _PopulatedDashboard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final mileage = NumberFormat('#,###').format(vehicle.mileage.round());
    final money = NumberFormat.simpleCurrency().format(0);

    return ListView(
      padding: EdgeInsets.all(tokens.space.s4),
      children: [
        Material(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          child: InkWell(
            onTap: () => context.push(AppRoutes.vehicleEdit(vehicle.id)),
            borderRadius: BorderRadius.circular(tokens.radius.md),
            child: Padding(
              padding: EdgeInsets.all(tokens.space.s4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radius.sm),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: vehicle.photoLocalPath == null
                          ? ColoredBox(
                              color: tokens.background.input,
                              child: Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
                            )
                          : Image.file(File(vehicle.photoLocalPath!), fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(width: tokens.space.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicle.yearMakeModel, style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: tokens.space.s1),
                        Text(
                          vehicle.licensePlate,
                          style: GoogleFonts.ibmPlexMono(color: tokens.text.accent, fontSize: 13),
                        ),
                        SizedBox(height: tokens.space.s2),
                        Text(
                          '$mileage ${vehicle.mileageUnit.label}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (vehicle.vin != null) ...[
                          SizedBox(height: tokens.space.s1),
                          Text(
                            vehicle.vin!,
                            style: GoogleFonts.ibmPlexMono(color: tokens.text.caption, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.space.s4),
        Text('Ownership Summary', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.space.s3),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Total spent', value: money)),
            SizedBox(width: tokens.space.s3),
            Expanded(child: _StatCard(label: 'This month', value: money)),
          ],
        ),
        SizedBox(height: tokens.space.s3),
        Row(
          children: [
            const Expanded(child: _StatCard(label: 'Services', value: '0')),
            SizedBox(width: tokens.space.s3),
            const Expanded(child: _StatCard(label: 'Documents', value: '0')),
          ],
        ),
        SizedBox(height: tokens.space.s5),
        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.space.s2),
        Text('No services yet', style: Theme.of(context).textTheme.bodySmall),
        SizedBox(height: tokens.space.s5),
        Text('Next Maintenance', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.space.s2),
        Text('No plan items yet', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: tokens.space.s2),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

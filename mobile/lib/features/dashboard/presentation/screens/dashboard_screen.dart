import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/features/dashboard/presentation/widgets/quick_actions_grid.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const recentActivityLimit = 3;

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

class _PopulatedDashboard extends ConsumerWidget {
  const _PopulatedDashboard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final mileage = MileageFormat.labeled(vehicle.mileage, lengthUnit);
    final money = NumberFormat.simpleCurrency().format(0);
    final history = ref.watch(maintenanceHistoryProvider).valueOrNull ?? const <ServiceRecord>[];
    final plan = ref.watch(maintenancePlanProvider).valueOrNull ?? const <PlanItem>[];
    final recent = history.take(DashboardScreen.recentActivityLimit).toList();
    final next = DueCalculator.nearest(
      items: plan,
      vehicleMileage: vehicle.mileage,
      now: DateTime.now(),
    );

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
                          mileage,
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
        SizedBox(height: tokens.space.s5),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.space.s3),
        QuickActionsGrid(
          items: [
            QuickActionItem(
              label: 'Services',
              icon: Icons.build_outlined,
              color: tokens.chart.maintenance,
              onTap: () => context.push(AppRoutes.serviceHistory),
            ),
            QuickActionItem(
              label: 'Documents',
              icon: Icons.folder_outlined,
              color: tokens.status.infoFg,
              onTap: () => context.push(AppRoutes.dashboardDocuments),
            ),
            QuickActionItem(
              label: 'Insurance',
              icon: Icons.shield_outlined,
              color: tokens.chart.insurance,
              onTap: () => context.push(AppRoutes.insurance),
            ),
            QuickActionItem(
              label: 'Parts',
              icon: Icons.settings_outlined,
              color: tokens.chart.parts,
              onTap: () => context.push(AppRoutes.parts),
            ),
          ],
        ),
        SizedBox(height: tokens.space.s5),
        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.space.s3),
        if (recent.isEmpty)
          Text(
            'No services yet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          )
        else
          ...recent.map(
            (record) => Padding(
              padding: EdgeInsets.only(bottom: tokens.space.s3),
              child: _RecentActivityRow(
                record: record,
                onTap: () => context.push(AppRoutes.serviceDetail(record.id)),
              ),
            ),
          ),
        SizedBox(height: tokens.space.s5),
        Text('Next Maintenance', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.space.s3),
        _NextMaintenanceCard(
          vehicle: vehicle,
          item: next,
          lengthUnit: lengthUnit,
          onLogService: next == null
              ? () => context.push(AppRoutes.maintenancePlan)
              : () {
                  ref.read(analyticsProvider).track(AnalyticsEvent.dashboardLogServiceTapped);
                  context.push(AppRoutes.maintenanceRegisterItem(next.id));
                },
        ),
      ],
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.record, required this.onTap});

  final ServiceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = record.items.isNotEmpty ? record.items.first.name : record.title;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(record.servicedOn),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                    ),
                    SizedBox(height: tokens.space.s1),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Text(
                NumberFormat.simpleCurrency().format(record.totalCost),
                style: GoogleFonts.ibmPlexMono(color: tokens.text.secondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextMaintenanceCard extends StatelessWidget {
  const _NextMaintenanceCard({
    required this.vehicle,
    required this.item,
    required this.lengthUnit,
    required this.onLogService,
  });

  final Vehicle vehicle;
  final PlanItem? item;
  final MileageUnit lengthUnit;
  final VoidCallback onLogService;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (item == null) {
      return Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No plan items yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
              ),
              SizedBox(height: tokens.space.s3),
              DcoButton(
                label: 'Add a plan item',
                variant: DcoButtonVariant.secondary,
                onPressed: onLogService,
              ),
            ],
          ),
        ),
      );
    }

    final urgency = DueCalculator.urgency(
      item: item!,
      vehicleMileage: vehicle.mileage,
      now: DateTime.now(),
    );
    final overdue = urgency == PlanUrgency.overdue;
    final dueColor = overdue
        ? tokens.feedback.overdue
        : urgency == PlanUrgency.dueSoon
        ? tokens.feedback.dueSoon
        : tokens.text.caption;

    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: Padding(
        padding: EdgeInsets.all(tokens.space.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item!.name, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: tokens.space.s2),
            Text(
              _dueCopy(item!, vehicle, lengthUnit),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dueColor),
            ),
            SizedBox(height: tokens.space.s4),
            DcoButton(label: 'Log Service', onPressed: onLogService),
          ],
        ),
      ),
    );
  }
}

String _dueCopy(PlanItem item, Vehicle vehicle, MileageUnit unit) {
  final now = DateTime.now();
  final today = DueCalculator.dateOnly(now);
  final overdue = DueCalculator.urgency(
        item: item,
        vehicleMileage: vehicle.mileage,
        now: now,
      ) ==
      PlanUrgency.overdue;
  final miles = NumberFormat('#,###');

  if (overdue) {
    final parts = <String>[];
    if (item.nextDueMileage != null && vehicle.mileage > item.nextDueMileage!) {
      parts.add(
        '${miles.format(unit.toDisplay(vehicle.mileage - item.nextDueMileage!).round())} ${unit.label}',
      );
    }
    if (item.nextDueOn != null) {
      final days = today.difference(DueCalculator.dateOnly(item.nextDueOn!)).inDays;
      if (days > 0) parts.add('$days ${days == 1 ? 'day' : 'days'}');
    }
    if (parts.isEmpty) return 'Overdue';
    return 'Overdue by ${parts.join(' / ')}';
  }

  final remainingMiles = item.nextDueMileage == null
      ? null
      : unit.toDisplay(item.nextDueMileage! - vehicle.mileage).round();
  final dateLabel = item.nextDueOn == null ? null : DateFormat.MMMd().format(item.nextDueOn!);
  if (remainingMiles != null && remainingMiles > 0 && dateLabel != null) {
    return 'Due in ${miles.format(remainingMiles)} ${unit.label} ($dateLabel)';
  }
  if (remainingMiles != null && remainingMiles > 0) {
    return 'Due in ${miles.format(remainingMiles)} ${unit.label}';
  }
  if (dateLabel != null) return 'Due $dateLabel';
  return 'Due soon';
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

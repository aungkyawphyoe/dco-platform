import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/features/dashboard/presentation/widgets/quick_actions_grid.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/providers.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
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
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final active = ref.watch(activeVehicleProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu, color: tokens.icon.active),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        titleSpacing: tokens.space.s4,
        title: InkWell(
          onTap: () => context.push(AppRoutes.garage),
          child: Row(
            children: [
              Icon(Icons.directions_car_outlined, color: tokens.icon.active),
              SizedBox(width: tokens.space.s2),
              Flexible(
                child: Text(
                  active.valueOrNull?.displayName ?? s.dashboardNoVehicle,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.icon.active),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: s.dashboardNotificationsTooltip,
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Icon(Icons.notifications_none, color: tokens.icon.active),
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
                  s.dashboardVerifyEmail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.status.warningFg,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => ref
                      .read(sessionControllerProvider.notifier)
                      .resendVerification(),
                  child: Text(
                    s.dashboardResend,
                    style: TextStyle(color: tokens.text.link),
                  ),
                ),
              ),
            ),
          if (session?.user.isProfileComplete == false)
            Material(
              color: tokens.status.infoBg,
              child: ListTile(
                title: Text(
                  s.profileCompleteBanner,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.status.infoFg),
                ),
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.settingsProfile),
                  child: Text(
                    s.profileCompleteBannerAction,
                    style: TextStyle(color: tokens.text.link),
                  ),
                ),
              ),
            ),
          Expanded(
            child: active.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: tokens.text.accent),
              ),
              error: (error, _) =>
                  DcoEmptyState(title: s.dashboardLoadError, body: '$error'),
              data: (vehicle) {
                if (vehicle == null) {
                  return DcoEmptyState(
                    title: s.dashboardEmptyTitle,
                    body: s.dashboardEmptyBody,
                    actionLabel: s.dashboardEmptyTitle,
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
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final mileage = MileageFormat.labeled(vehicle.mileage, lengthUnit);
    final currency = ref.watch(currencyProvider).code;
    // final summary =
    //     ref.watch(vehicleExpenseSummaryProvider).valueOrNull ??
    //     ExpenseSummary.empty;
    // final moneyTotal = MoneyFormat.labeled(summary.total, currency);
    // final moneyMonth = MoneyFormat.labeled(summary.thisMonth, currency);
    final history =
        ref.watch(maintenanceHistoryProvider).valueOrNull ??
        const <ServiceRecord>[];
    final plan =
        ref.watch(maintenancePlanProvider).valueOrNull ?? const <PlanItem>[];
    final recent = history.take(DashboardScreen.recentActivityLimit).toList();
    final next = DueCalculator.nearest(
      items: plan,
      vehicleMileage: vehicle.mileage,
      now: DateTime.now(),
    );

    return ListView(
      padding: EdgeInsets.all(tokens.space.s4),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            border: Border(
              left: BorderSide(color: tokens.text.accent, width: 3),
            ),
            boxShadow: tokens.shadows.card,
          ),
          child: Material(
            color: tokens.background.card,
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            child: InkWell(
              onTap: () => context.push(AppRoutes.vehicleDetail(vehicle.id)),
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              child: Padding(
                padding: EdgeInsets.all(tokens.space.s4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.radius.md),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: vehicle.photoLocalPath == null
                            ? ColoredBox(
                                color: tokens.background.input,
                                child: Icon(
                                  Icons.directions_car_outlined,
                                  color: tokens.icon.inactive,
                                ),
                              )
                            : Image.file(
                                File(vehicle.photoLocalPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: tokens.background.input,
                                  child: Icon(
                                    Icons.directions_car_outlined,
                                    color: tokens.icon.inactive,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: tokens.space.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.yearMakeModel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: tokens.space.s1),
                          Text(
                            vehicle.licensePlate,
                            style: GoogleFonts.ibmPlexMono(
                              color: tokens.text.accent,
                              fontSize: 13,
                            ),
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
                              style: GoogleFonts.ibmPlexMono(
                                color: tokens.text.caption,
                                fontSize: 12,
                              ),
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
        ),
        SizedBox(height: tokens.space.s5),
        // Text(
        //   s.dashboardOwnershipSummary,
        //   style: Theme.of(context).textTheme.titleLarge,
        // ),
        // SizedBox(height: tokens.space.s3),
        // Row(
        //   children: [
        //     Expanded(
        //       child: _StatCard(label: s.dashboardTotalSpent, value: moneyTotal),
        //     ),
        //     SizedBox(width: tokens.space.s3),
        //     Expanded(
        //       child: _StatCard(label: s.dashboardThisMonth, value: moneyMonth),
        //     ),
        //   ],
        // ),
        // SizedBox(height: tokens.space.s5),
        Text(
          s.dashboardQuickActions,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: tokens.space.s3),
        QuickActionsGrid(
          items: [
            QuickActionItem(
              label: s.dashboardLogService,
              icon: Icons.car_repair,
              color: tokens.chart.maintenance,
              onTap: () => context.push(AppRoutes.maintenanceRegister),
            ),
            QuickActionItem(
              label: s.dashboardHistory,
              icon: Icons.work_history_outlined,
              color: tokens.chart.maintenance,
              onTap: () => context.push(AppRoutes.serviceHistory),
            ),
            QuickActionItem(
              label: vehicle.fuelType == FuelType.electric
                  ? s.dashboardCharge
                  : s.dashboardRefuel,
              icon: vehicle.fuelType == FuelType.electric
                  ? Icons.bolt_outlined
                  : Icons.local_gas_station_outlined,
              color: tokens.chart.fuel,
              onTap: () => context.push(AppRoutes.fuelLogs),
            ),
            QuickActionItem(
              label: s.dashboardNotes,
              icon: Icons.notes_outlined,
              color: tokens.chart.other,
              onTap: () => context.push(AppRoutes.notes),
            ),
          ],
        ),
        SizedBox(height: tokens.space.s1),
        Text(
          s.dashboardRecentActivity,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: tokens.space.s3),
        if (recent.isEmpty)
          Text(
            s.dashboardNoServicesYet,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
          )
        else
          ...recent.map(
            (record) => Padding(
              padding: EdgeInsets.only(bottom: tokens.space.s3),
              child: _RecentActivityRow(
                record: record,
                currency: currency,
                onTap: () => context.push(AppRoutes.serviceDetail(record.id)),
              ),
            ),
          ),
        SizedBox(height: tokens.space.s5),
        Text(
          s.dashboardNextMaintenance,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: tokens.space.s3),
        _NextMaintenanceCard(
          vehicle: vehicle,
          item: next,
          lengthUnit: lengthUnit,
          onLogService: next == null
              ? () => context.push(AppRoutes.maintenancePlan)
              : () {
                  ref
                      .read(analyticsProvider)
                      .track(AnalyticsEvent.dashboardLogServiceTapped);
                  context.push(AppRoutes.maintenanceRegisterItem(next.id));
                },
        ),
        SizedBox(height: tokens.space.s7),
      ],
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({
    required this.record,
    required this.currency,
    required this.onTap,
  });

  final ServiceRecord record;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = record.items.isNotEmpty
        ? record.items.first.name
        : record.title;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        boxShadow: tokens.shadows.card,
      ),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.caption,
                        ),
                      ),
                      SizedBox(height: tokens.space.s1),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  MoneyFormat.labeled(record.totalCost, currency),
                  style: GoogleFonts.ibmPlexMono(
                    color: tokens.text.secondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    if (item == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          boxShadow: tokens.shadows.card,
        ),
        child: Material(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          child: Padding(
            padding: EdgeInsets.all(tokens.space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.dashboardNoPlanItemsYet,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.text.secondary,
                  ),
                ),
                SizedBox(height: tokens.space.s3),
                DcoButton(
                  label: s.dashboardAddPlanItem,
                  variant: DcoButtonVariant.secondary,
                  onPressed: onLogService,
                ),
              ],
            ),
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
    final borderColor = overdue
        ? tokens.feedback.overdue
        : urgency == PlanUrgency.dueSoon
        ? tokens.feedback.dueSoon
        : tokens.status.successFg;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
        boxShadow: tokens.shadows.card,
      ),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item!.name, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: tokens.space.s2),
              Text(
                _dueCopy(item!, vehicle, lengthUnit, s),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: dueColor),
              ),
              SizedBox(height: tokens.space.s4),
              DcoButton(label: s.dashboardLogService, onPressed: onLogService),
            ],
          ),
        ),
      ),
    );
  }
}

String _dueCopy(
  PlanItem item,
  Vehicle vehicle,
  MileageUnit unit,
  AppLocalizations s,
) {
  final now = DateTime.now();
  final today = DueCalculator.dateOnly(now);
  final overdue =
      DueCalculator.urgency(
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
      final days = today
          .difference(DueCalculator.dateOnly(item.nextDueOn!))
          .inDays;
      if (days > 0) parts.add(s.overdueBy(days));
    }
    if (parts.isEmpty) return s.overdue;
    return '${s.overdue} ${parts.join(' / ')}';
  }

  final remainingMiles = item.nextDueMileage == null
      ? null
      : unit.toDisplay(item.nextDueMileage! - vehicle.mileage).round();
  final dateLabel = item.nextDueOn == null
      ? null
      : DateFormat.MMMd().format(item.nextDueOn!);
  if (remainingMiles != null && remainingMiles > 0 && dateLabel != null) {
    return s.dueIn(
      '${miles.format(remainingMiles)} ${unit.label} ($dateLabel)',
    );
  }
  if (remainingMiles != null && remainingMiles > 0) {
    return s.dueIn('${miles.format(remainingMiles)} ${unit.label}');
  }
  if (dateLabel != null) return s.due(dateLabel);
  return s.dueSoon;
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.background.card,
            tokens.background.card.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        border: Border(
          top: BorderSide(
            color: tokens.text.accent.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        boxShadow: tokens.shadows.card,
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

import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_layout.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/domain/registration_expiry.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_access.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/tire_service_finder.dart';
import 'package:dco_mobile/features/maintenance/domain/vehicle_health.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/service_history_list.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Vehicle detail: photo hero plus Overview / Maintenance / Details tabs.
/// The primary vehicle action (log service) is pinned to the thumb zone;
/// sharing and editing are quiet header actions.
class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  /// Opens a screen scoped to the active vehicle. Viewing works for any
  /// vehicle, but acting on one makes it active first.
  Future<void> _openForVehicle(String route) async {
    final activeId = ref.read(activeVehicleProvider).valueOrNull?.id;
    if (activeId != null && activeId != widget.vehicleId) {
      try {
        await ref.read(setActiveVehicleProvider)(widget.vehicleId);
        ref.read(analyticsProvider).track(AnalyticsEvent.vehicleSwitched);
      } catch (_) {
        // Best effort; navigation still proceeds.
      }
      if (!mounted) return;
    }
    context.push(route);
  }

  void _push(String route) {
    if (mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));

    if (vehicleAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(s.vehicleDetailTitle)),
        body: Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
      );
    }

    final vehicle = vehicleAsync.valueOrNull;
    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.vehicleDetailTitle)),
        body: DcoEmptyState(
          title: s.vehicleDetailNotFound,
          body: s.vehicleDetailNotFoundBody,
        ),
      );
    }

    final activeId = ref.watch(activeVehicleProvider).valueOrNull?.id;
    final currentUserId = ref.watch(currentUserIdProvider);
    final canEdit = vehicle.userId == currentUserId;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 264,
              backgroundColor: tokens.background.primary,
              surfaceTintColor: Colors.transparent,
              foregroundColor: tokens.text.primary,
              title: Text(
                vehicle.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              actions: [
                if (canEdit)
                  _RoundIconButton(
                    tooltip: s.vehicleEditTooltip,
                    icon: Icons.edit_outlined,
                    onPressed: () => _push(AppRoutes.vehicleEdit(vehicle.id)),
                  ),
                if (vehicle.source == VehicleSource.owned)
                  _RoundIconButton(
                    tooltip: s.vehicleShareTooltip,
                    icon: Icons.ios_share,
                    onPressed: () =>
                        context.push(AppRoutes.vehicleShareManage(vehicle.id)),
                  ),
                SizedBox(width: tokens.space.s2),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _VehicleHero(
                  vehicle: vehicle,
                  isActive: activeId == vehicle.id,
                  lengthUnit: ref.watch(lengthUnitProvider),
                  onSetActive: () async {
                    try {
                      await ref.read(setActiveVehicleProvider)(
                        widget.vehicleId,
                      );
                      ref
                          .read(analyticsProvider)
                          .track(AnalyticsEvent.vehicleSwitched);
                    } catch (_) {
                      // Best effort.
                    }
                  },
                ),
              ),
              bottom: TabBar(
                labelColor: tokens.text.accent,
                unselectedLabelColor: tokens.text.secondary,
                indicatorColor: tokens.text.accent,
                indicatorWeight: 2,
                dividerColor: tokens.border.divider,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
                tabs: [
                  Tab(text: s.vehicleDetailTabOverview),
                  Tab(text: s.vehicleDetailTabMaintenance),
                  Tab(text: s.vehicleDetailTabDetails),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(
                vehicle: vehicle,
                onPush: _push,
                onOpenForVehicle: _openForVehicle,
              ),
              ServiceHistoryList(vehicleId: vehicle.id),
              _DetailsTab(vehicle: vehicle),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({
    required this.vehicle,
    required this.isActive,
    required this.lengthUnit,
    required this.onSetActive,
  });

  final Vehicle vehicle;
  final bool isActive;
  final MileageUnit lengthUnit;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final hasPhoto =
        vehicle.photoLocalPath != null && vehicle.photoLocalPath!.isNotEmpty;
    final mileage = MileageFormat.labeled(vehicle.mileage, lengthUnit);

    return Container(
      color: tokens.background.primary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            Image.file(
              File(vehicle.photoLocalPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: tokens.background.secondary,
                child: Center(
                  child: Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: tokens.icon.inactive,
                  ),
                ),
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.background.secondary,
                    tokens.background.input,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.directions_car_filled,
                  size: 120,
                  color: tokens.text.accent.withValues(alpha: 0.16),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.background.primary.withValues(alpha: 0.85),
                      tokens.background.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.background.primary.withValues(alpha: 0),
                      tokens.background.primary,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: DcoLayout.cardPaddingLoose,
            right: DcoLayout.cardPaddingLoose,
            bottom: kTextTabBarHeight + tokens.space.s2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(child: _PlateChip(text: vehicle.licensePlate)),
                    SizedBox(width: tokens.space.s2),
                    Text(
                      mileage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 12,
                        color: tokens.text.secondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space.s2),
                Row(
                  children: [
                    if (isActive)
                      _HeroBadge(
                        label: s.active,
                        color: tokens.text.accent,
                        background: tokens.background.navActive,
                      ),
                    if (isActive && vehicle.source == VehicleSource.shared)
                      SizedBox(width: tokens.space.s2),
                    if (vehicle.source == VehicleSource.shared)
                      _HeroBadge(
                        label: s.garageSharedBadge,
                        color: tokens.status.infoFg,
                        background: tokens.status.infoBg,
                      ),
                    const Spacer(),
                    if (!isActive) _SetActiveChip(onTap: onSetActive),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1,
      ),
      decoration: BoxDecoration(
        color: tokens.background.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(tokens.radius.full),
        border: Border.all(color: tokens.border.divider),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: tokens.text.primary,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(right: tokens.space.s1),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: tokens.background.secondary,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border.divider),
              ),
              child: Icon(icon, size: 18, color: tokens.icon.inactive),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radius.full),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _SetActiveChip extends StatelessWidget {
  const _SetActiveChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.full),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(horizontal: tokens.space.s3),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border.defaultColor),
            borderRadius: BorderRadius.circular(tokens.radius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: tokens.icon.inactive,
              ),
              SizedBox(width: tokens.space.s1),
              Text(
                s.vehicleDetailSetActive,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: tokens.text.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Overview tab ────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.vehicle,
    required this.onPush,
    required this.onOpenForVehicle,
  });

  final Vehicle vehicle;
  final void Function(String route) onPush;
  final Future<void> Function(String route) onOpenForVehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final plan =
        ref.watch(maintenancePlanForVehicleProvider(vehicle.id)).valueOrNull ??
        const <PlanItem>[];
    final history =
        ref
            .watch(maintenanceHistoryForVehicleProvider(vehicle.id))
            .valueOrNull ??
        const [];
    final documents =
        ref.watch(documentsForVehicleProvider(vehicle.id)).valueOrNull ??
        const <Document>[];
    final thresholds = ref.watch(reminderThresholdsProvider);
    final lengthUnit = ref.watch(lengthUnitProvider);
    final access = VehicleAccess.of(vehicle, ref.watch(currentUserIdProvider));

    final now = DateTime.now();
    final next = DueCalculator.nearest(
      items: plan,
      vehicleMileage: vehicle.mileage,
      now: now,
      thresholds: thresholds,
    );
    final health = VehicleHealthCalculator.evaluate(
      items: plan,
      vehicleMileage: vehicle.mileage,
      now: now,
      thresholds: thresholds,
    );
    final tire = TireServiceFinder.latest(history);
    final registration = RegistrationExpiryFinder.summarize(documents);

    final urgency = next == null
        ? null
        : DueCalculator.urgency(
            item: next,
            vehicleMileage: vehicle.mileage,
            now: now,
            thresholds: thresholds,
          );

    final healthValue = plan.isEmpty
        ? s.vehicleDetailNoPlan
        : health.overdueCount > 0
        ? '${health.overdueCount} ${s.overdue}'
        : health.dueSoonCount > 0
        ? '${health.dueSoonCount} ${s.dueSoon}'
        : s.vehicleDetailHealthGood;
    final healthParts = <String>[
      if (health.overdueCount > 0 && health.dueSoonCount > 0)
        '${health.dueSoonCount} ${s.dueSoon}',
      if (health.scheduledCount > 0)
        '${health.scheduledCount} ${s.maintenanceScheduled}',
    ];
    final healthSubtitle = plan.isEmpty || healthParts.isEmpty
        ? null
        : healthParts.join(' · ');

    VoidCallback? registrationTap;
    final registrationDocument = registration.document;
    if (registrationDocument == null) {
      if (access.canCreate) {
        registrationTap = () => onPush(
          '${AppRoutes.documentNew}'
          '?vehicle=${vehicle.id}&category=registration',
        );
      }
    } else if (access.canEditRecord(registrationDocument.createdBy)) {
      registrationTap = () =>
          onPush(AppRoutes.documentEdit(registrationDocument.id));
    } else if (registrationDocument.hasLocalFile ||
        registrationDocument.mediaId != null) {
      registrationTap = () =>
          onPush(AppRoutes.documentView(registrationDocument.id));
    }

    return ListView(
      padding: const EdgeInsets.all(DcoLayout.screenPadding),
      children: [
        Text(
          s.vehicleDetailNextService,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: tokens.space.s3),
        _NextServiceCard(
          next: next,
          urgency: urgency,
          dueCopy: next == null
              ? null
              : _nextServiceCopy(next, urgency!, vehicle, lengthUnit, s),
          onTap: next == null || !access.canCreate
              ? () => onOpenForVehicle(AppRoutes.maintenancePlan)
              : () => onOpenForVehicle(
                  AppRoutes.maintenanceRegisterItem(next.id),
                ),
        ),
        SizedBox(height: DcoLayout.sectionGap),
        _OverviewTile(
          icon: Icons.health_and_safety_outlined,
          iconBackground: switch (health.status) {
            VehicleHealth.attention => tokens.status.dangerBg,
            VehicleHealth.dueSoon => tokens.status.warningBg,
            VehicleHealth.good =>
              plan.isEmpty ? tokens.status.infoBg : tokens.status.successBg,
          },
          iconColor: switch (health.status) {
            VehicleHealth.attention => tokens.status.dangerFg,
            VehicleHealth.dueSoon => tokens.status.warningFg,
            VehicleHealth.good =>
              plan.isEmpty ? tokens.status.infoFg : tokens.status.successFg,
          },
          title: s.vehicleDetailHealth,
          value: healthValue,
          valueColor: plan.isEmpty
              ? tokens.text.secondary
              : switch (health.status) {
                  VehicleHealth.attention => tokens.feedback.overdue,
                  VehicleHealth.dueSoon => tokens.feedback.dueSoon,
                  VehicleHealth.good => tokens.status.successFg,
                },
          subtitle: healthSubtitle,
          subtitleColor: tokens.text.caption,
        ),
        SizedBox(height: tokens.space.s2),
        _OverviewTile(
          icon: Icons.tire_repair_outlined,
          iconBackground: tire == null
              ? tokens.status.infoBg
              : tokens.status.successBg,
          iconColor: tire == null
              ? tokens.status.infoFg
              : tokens.status.successFg,
          title: s.vehicleDetailTire,
          value: tire == null
              ? s.vehicleDetailNoTireService
              : DateFormat.yMMMd().format(tire.servicedOn),
          valueColor: tire == null ? tokens.text.secondary : null,
          onTap: tire != null
              ? () => onPush(AppRoutes.serviceDetail(tire.id))
              : access.canCreate
              ? () => onOpenForVehicle(AppRoutes.maintenanceRegister)
              : null,
        ),
        SizedBox(height: tokens.space.s2),
        _OverviewTile(
          icon: Icons.event_outlined,
          iconBackground: switch (registration.status) {
            RegistrationExpiryStatus.expired => tokens.status.dangerBg,
            RegistrationExpiryStatus.dueSoon => tokens.status.warningBg,
            _ => tokens.status.infoBg,
          },
          iconColor: switch (registration.status) {
            RegistrationExpiryStatus.expired => tokens.status.dangerFg,
            RegistrationExpiryStatus.dueSoon => tokens.status.warningFg,
            _ => tokens.status.infoFg,
          },
          title: s.vehicleDetailLicenseDue,
          value: switch (registration.status) {
            RegistrationExpiryStatus.none => s.vehicleDetailAddRegistration,
            RegistrationExpiryStatus.valid => DateFormat.yMMMd().format(
              registration.expiresOn!,
            ),
            RegistrationExpiryStatus.dueSoon => DateFormat.yMMMd().format(
              registration.expiresOn!,
            ),
            RegistrationExpiryStatus.expired => DateFormat.yMMMd().format(
              registration.expiresOn!,
            ),
          },
          valueColor: switch (registration.status) {
            RegistrationExpiryStatus.none => tokens.text.link,
            RegistrationExpiryStatus.valid => null,
            RegistrationExpiryStatus.dueSoon => tokens.feedback.dueSoon,
            RegistrationExpiryStatus.expired => tokens.feedback.overdue,
          },
          subtitle: switch (registration.status) {
            RegistrationExpiryStatus.dueSoon => s.dueIn(
              DateFormat.MMMd().format(registration.expiresOn!),
            ),
            RegistrationExpiryStatus.expired => s.vehicleDetailExpired,
            _ => null,
          },
          subtitleColor: switch (registration.status) {
            RegistrationExpiryStatus.dueSoon => tokens.feedback.dueSoon,
            RegistrationExpiryStatus.expired => tokens.feedback.overdue,
            _ => null,
          },
          onTap: registrationTap,
        ),
      ],
    );
  }

  String _nextServiceCopy(
    PlanItem item,
    PlanUrgency urgency,
    Vehicle vehicle,
    MileageUnit unit,
    AppLocalizations s,
  ) {
    final now = DateTime.now();
    final today = DueCalculator.dateOnly(now);
    final miles = NumberFormat('#,###');

    if (urgency == PlanUrgency.overdue) {
      final parts = <String>[];
      if (item.nextDueOn != null) {
        final days = today
            .difference(DueCalculator.dateOnly(item.nextDueOn!))
            .inDays;
        if (days > 0) parts.add(s.overdueBy(days));
      }
      if (item.nextDueMileage != null &&
          vehicle.mileage > item.nextDueMileage!) {
        parts.add(
          '${miles.format(unit.toDisplay(vehicle.mileage - item.nextDueMileage!).round())} ${unit.label}',
        );
      }
      return parts.isEmpty ? s.overdue : parts.join(' · ');
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
}

class _ChevronCircle extends StatelessWidget {
  const _ChevronCircle();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: tokens.background.secondary,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.chevron_right, size: 18, color: tokens.text.secondary),
    );
  }
}

class _NextServiceCard extends StatelessWidget {
  const _NextServiceCard({
    required this.next,
    required this.urgency,
    required this.dueCopy,
    required this.onTap,
  });

  final PlanItem? next;
  final PlanUrgency? urgency;
  final String? dueCopy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final item = next;
    final isOverdue = urgency == PlanUrgency.overdue;
    final isDueSoon = urgency == PlanUrgency.dueSoon;
    final statusColor = isOverdue
        ? tokens.status.dangerFg
        : isDueSoon
        ? tokens.status.warningFg
        : tokens.status.successFg;
    final statusBg = isOverdue
        ? tokens.status.dangerBg
        : isDueSoon
        ? tokens.status.warningBg
        : tokens.status.successBg;
    final radius = BorderRadius.circular(tokens.radius.lg);

    return Material(
      color: tokens.background.card,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(DcoLayout.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: item == null
                  ? tokens.border.divider
                  : statusColor.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (item == null)
                    Icon(
                      Icons.build_outlined,
                      size: 16,
                      color: tokens.icon.inactive,
                    )
                  else if (isOverdue || isDueSoon)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space.s2,
                        vertical: tokens.space.s1,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(tokens.radius.full),
                      ),
                      child: Text(
                        (isOverdue ? s.overdue : s.dueSoon).toUpperCase(),
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: statusColor),
                      ),
                    )
                  else
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: statusColor,
                    ),
                  const Spacer(),
                  const _ChevronCircle(),
                ],
              ),
              SizedBox(height: tokens.space.s2),
              Text(
                item?.name ?? s.vehicleDetailNoPlan,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (dueCopy != null) ...[
                SizedBox(height: tokens.space.s1),
                Text(
                  dueCopy!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isOverdue || isDueSoon
                        ? statusColor
                        : tokens.text.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.value,
    this.onTap,
    this.valueColor,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String value;
  final Color? valueColor;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.radius.md);
    return Material(
      color: tokens.background.card,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space.s3,
            vertical: tokens.space.s3,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: tokens.border.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodySmall),
                    SizedBox(height: tokens.space.s1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: valueColor ?? tokens.text.primary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: tokens.space.s1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subtitleColor ?? tokens.text.caption,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) const _ChevronCircle(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Details tab ─────────────────────────────────────────────────────────

class _DetailsTab extends ConsumerWidget {
  const _DetailsTab({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);

    final rows = <(String, String, bool)>[
      (s.vehicleDetailName, vehicle.name, false),
      (s.vehicleDetailYear, vehicle.year.toString(), false),
      (s.vehicleDetailMake, vehicle.make, false),
      (s.vehicleDetailModel, vehicle.model, false),
      (s.vehicleDetailPlate, vehicle.licensePlate, true),
      (
        s.vehicleDetailMileage,
        MileageFormat.labeled(vehicle.mileage, lengthUnit),
        true,
      ),
      (s.vehicleDetailFuelType, vehicle.fuelType.label, false),
      if (vehicle.vin != null && vehicle.vin!.isNotEmpty)
        (s.vehicleVinLabel, vehicle.vin!, true),
      if (vehicle.color != null && vehicle.color!.isNotEmpty)
        (s.vehicleDetailColor, vehicle.color!, false),
      if (vehicle.nickname != null && vehicle.nickname!.isNotEmpty)
        (s.vehicleNicknameLabel, vehicle.nickname!, false),
      if (vehicle.purchaseDate != null)
        (
          s.vehiclePurchaseDateLabel,
          DateFormat.yMMMd().format(vehicle.purchaseDate!),
          false,
        ),
      (
        s.vehicleDetailPhoto,
        vehicle.photoLocalPath != null && vehicle.photoLocalPath!.isNotEmpty
            ? s.vehicleDetailPhotoAdded
            : s.vehicleDetailPhotoNone,
        false,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(DcoLayout.screenPadding),
      children: [
        Container(
          decoration: BoxDecoration(
            color: tokens.background.card,
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            border: Border.all(color: tokens.border.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: tokens.border.divider),
                _DetailRow(
                  label: rows[i].$1,
                  value: rows[i].$2,
                  mono: rows[i].$3,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.mono,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final valueStyle = mono
        ? GoogleFonts.ibmPlexMono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.text.primary,
          )
        : Theme.of(context).textTheme.bodyLarge;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s4,
        vertical: tokens.space.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(width: tokens.space.s3),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

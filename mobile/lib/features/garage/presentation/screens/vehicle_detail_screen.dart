import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/domain/registration_expiry.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
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

/// Vehicle detail: collapsing photo hero plus Overview / Maintenance /
/// Details tabs. Opens for any vehicle — owned or shared with the user.
/// Edit is only offered for vehicles the current user owns; members keep
/// view access plus "Set active" so they can log against the shared car.
class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  /// Opens a screen that is scoped to the active vehicle. Viewing can be
  /// done for any vehicle, but acting on one makes it the active vehicle.
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
              expandedHeight: 320,
              backgroundColor: tokens.background.primary,
              surfaceTintColor: Colors.transparent,
              title: Text(
                s.vehicleDetailTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              actions: [
                if (vehicle.source == VehicleSource.owned)
                  IconButton(
                    tooltip: s.vehicleShareTooltip,
                    onPressed: () => context.push(
                      AppRoutes.vehicleShareManage(vehicle.id),
                    ),
                    icon: Icon(
                      Icons.ios_share,
                      size: 20,
                      color: tokens.icon.inactive,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _VehicleHero(
                  vehicle: vehicle,
                  isActive: activeId == vehicle.id,
                  canEdit: canEdit,
                  onEdit: () => _push(AppRoutes.vehicleEdit(vehicle.id)),
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
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
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
    required this.canEdit,
    required this.onEdit,
    required this.onSetActive,
  });

  final Vehicle vehicle;
  final bool isActive;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final hasPhoto =
        vehicle.photoLocalPath != null && vehicle.photoLocalPath!.isNotEmpty;

    final background = tokens.background.primary;

    return Container(
      width: double.infinity,
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding),
          Stack(
            children: [
              if (hasPhoto)
                Positioned.fill(
                  child: Image.file(
                    File(vehicle.photoLocalPath!),
                    fit: BoxFit.cover,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 150 - tokens.space.s5,
                    width: double.infinity,
                    child: hasPhoto
                        ? null
                        : ColoredBox(
                            color: tokens.background.primary,
                            child: Center(
                              child: Icon(
                                Icons.directions_car_outlined,
                                size: 64,
                                color: tokens.icon.inactive,
                              ),
                            ),
                          ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      tokens.space.s5,
                      tokens.space.s3,
                      tokens.space.s5,
                      tokens.space.s3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          background.withValues(alpha: 0),
                          background.withValues(alpha: 0.75),
                          background,
                        ],
                        stops: const [0, 0.14, 0.35],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              vehicle.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Spacer(),
                            if (!isActive) ...[
                              SizedBox(height: tokens.space.s1),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _SetActiveChip(onTap: onSetActive),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              vehicle.licensePlate,
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 14,
                                color: tokens.text.accent,
                              ),
                            ),
                            const Spacer(),
                            if (canEdit)
                              TextButton(
                                onPressed: onEdit,
                                child: Text(
                                  s.edit,
                                  style: TextStyle(color: tokens.text.link),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space.s3,
            vertical: tokens.space.s2,
          ),
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
                color: tokens.icon.active,
              ),
              SizedBox(width: tokens.space.s1),
              Text(
                s.vehicleDetailSetActive,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text.link),
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
    final urgencyColor = switch (urgency) {
      PlanUrgency.overdue => tokens.feedback.overdue,
      PlanUrgency.dueSoon => tokens.feedback.dueSoon,
      _ => tokens.text.caption,
    };
    final urgencyIconColor = switch (urgency) {
      PlanUrgency.overdue => tokens.status.dangerFg,
      PlanUrgency.dueSoon => tokens.status.warningFg,
      _ => tokens.status.infoFg,
    };
    final urgencyIconBg = switch (urgency) {
      PlanUrgency.overdue => tokens.status.dangerBg,
      PlanUrgency.dueSoon => tokens.status.warningBg,
      _ => tokens.status.infoBg,
    };

    return ListView(
      padding: EdgeInsets.all(tokens.space.s4),
      children: [
        _OverviewTile(
          icon: Icons.build_outlined,
          iconBackground: urgencyIconBg,
          iconColor: urgencyIconColor,
          title: s.vehicleDetailNextService,
          value: next?.name ?? s.vehicleDetailNoPlan,
          valueColor: next == null ? tokens.text.secondary : null,
          subtitle: next == null
              ? null
              : _nextServiceCopy(next, urgency!, vehicle, lengthUnit, s),
          subtitleColor: urgencyColor,
          onTap: next == null
              ? () => onOpenForVehicle(AppRoutes.maintenancePlan)
              : () => onOpenForVehicle(
                  AppRoutes.maintenanceRegisterItem(next.id),
                ),
        ),
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
          value: plan.isNotEmpty
              ? switch (health.status) {
                  VehicleHealth.attention => s.vehicleDetailHealthAttention,
                  VehicleHealth.dueSoon => s.dueSoon,
                  VehicleHealth.good => s.vehicleDetailHealthGood,
                }
              : s.vehicleDetailNoPlan,
          valueColor: switch (health.status) {
            VehicleHealth.attention => tokens.feedback.overdue,
            VehicleHealth.dueSoon => tokens.feedback.dueSoon,
            VehicleHealth.good =>
              plan.isEmpty ? tokens.text.secondary : tokens.status.successFg,
          },
          onTap: () => (),
        ),
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
          onTap: tire == null
              ? () => onOpenForVehicle(AppRoutes.maintenanceRegister)
              : () => onPush(AppRoutes.serviceDetail(tire.id)),
        ),
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
          onTap: () {
            final doc = registration.document;
            if (doc == null) {
              onPush(
                '${AppRoutes.documentNew}'
                '?vehicle=${vehicle.id}&category=registration',
              );
            } else {
              onPush(AppRoutes.documentEdit(doc.id));
            }
          },
        ),
        SizedBox(height: tokens.space.s3),
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
      final parts = <String>[s.overdue];
      if (item.nextDueMileage != null &&
          vehicle.mileage > item.nextDueMileage!) {
        parts.add(
          '${miles.format(unit.toDisplay(vehicle.mileage - item.nextDueMileage!).round())} ${unit.label}',
        );
      }
      if (item.nextDueOn != null) {
        final days = today
            .difference(DueCalculator.dateOnly(item.nextDueOn!))
            .inDays;
        if (days > 0) {
          return '${s.overdue} ${s.overdueBy(days)}';
        }
      }
      return parts.join(' ');
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

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s3),
      child: Container(
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
              padding: EdgeInsets.all(tokens.space.s4),
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
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.secondary),
                        ),
                        SizedBox(height: tokens.space.s1),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: valueColor ?? tokens.text.primary,
                              ),
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: tokens.space.s1),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: subtitleColor ?? tokens.text.caption,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.icon.inactive),
                ],
              ),
            ),
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
      padding: EdgeInsets.all(tokens.space.s5),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            boxShadow: tokens.shadows.card,
          ),
          child: Material(
            color: tokens.background.card,
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.s4,
                vertical: tokens.space.s2,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: tokens.border.defaultColor),
                    _DetailRow(
                      label: rows[i].$1,
                      value: rows[i].$2,
                      mono: rows[i].$3,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.space.s5),
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
        ? GoogleFonts.ibmPlexMono(fontSize: 14, color: tokens.text.primary)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
          ),
          SizedBox(width: tokens.space.s3),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

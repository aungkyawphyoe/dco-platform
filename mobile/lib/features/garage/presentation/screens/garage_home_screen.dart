import 'dart:async';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/gating/gate_messages.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_layout.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_error_dialog.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/presentation/widgets/vehicle_card.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GarageHomeScreen extends ConsumerWidget {
  const GarageHomeScreen({super.key, this.embedded = false});

  final bool embedded;

  /// Entry-point gate (§8.3 / §2): over-cap users never reach the form —
  /// the add CTA is replaced by the limit caption. A null gate (hydrating)
  /// still navigates: the form's save re-checks and denies.
  void _openAddVehicle(BuildContext context, WidgetRef ref) {
    final gate = ref.read(featureGateProvider);
    if (gate != null && !gate.canCreateVehicle) {
      final s = AppLocalizations.of(context)!;
      unawaited(
        showDcoErrorDialog(
          context,
          title: s.planLimitTitle,
          actionLabel: s.pricingViewPlans,
          onAction: () {
            if (context.mounted) context.push(AppRoutes.pricing);
          },
          message: gate.vehicleBlockMessage(s),
        ),
      );
      return;
    }
    context.push(AppRoutes.vehicleNew);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicles = ref.watch(garageVehiclesProvider);
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final gate = ref.watch(featureGateProvider);
    final personal = ref.watch(driverOrganizationIdProvider) == null;
    final canAddVehicle = personal && (gate?.canCreateVehicle ?? true);

    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(s.garageMyGarage)),
      body: vehicles.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) =>
            DcoEmptyState(title: s.garageLoadError, body: '$error'),
        data: (allItems) {
          final items = personal
              ? allItems.where((v) => v.source == VehicleSource.owned).toList()
              : allItems;
          if (items.isEmpty) {
            return const _GarageEmpty();
          }
          final ordered = _activeFirst(items, active?.id);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              DcoLayout.screenPadding,
              DcoLayout.screenPadding,
              DcoLayout.screenPadding,
              personal ? DcoLayout.bottomBarInset : DcoLayout.screenPadding,
            ),
            children: [
              for (final vehicle in ordered)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.space.s2),
                  child: VehicleCard(
                    vehicle: vehicle,
                    isActive: vehicle.id == active?.id,
                    lengthUnit: lengthUnit,
                    onOpen: () =>
                        context.push(AppRoutes.vehicleDetail(vehicle.id)),
                    onEdit: personal && vehicle.source == VehicleSource.owned
                        ? () => context.push(AppRoutes.vehicleEdit(vehicle.id))
                        : null,
                    onShare: personal && vehicle.source == VehicleSource.owned
                        ? () => context.push(
                            AppRoutes.vehicleShareManage(vehicle.id),
                          )
                        : null,
                    onSetActive: vehicle.id == active?.id || userId == null
                        ? null
                        : () async {
                            try {
                              await ref.read(setActiveVehicleProvider)(
                                vehicle.id,
                              );
                              ref
                                  .read(analyticsProvider)
                                  .track(AnalyticsEvent.vehicleSwitched);
                            } catch (_) {
                              if (context.mounted) {
                                unawaited(
                                  showDcoErrorDialog(
                                    context,
                                    title: s.garageSwitchFailed,
                                    message: s.garageSwitchFailedBody,
                                  ),
                                );
                              }
                              return;
                            }
                            if (context.mounted) {
                              context.go(AppRoutes.dashboard);
                            }
                          },
                  ),
                ),
              if (personal && !embedded) ...[
                SizedBox(height: DcoLayout.sectionGap),
                _GarageLinkRow(
                  icon: Icons.people_outline,
                  label: s.drawerSharedWithMe,
                  onTap: () => context.push(AppRoutes.sharedWithMe),
                ),
                SizedBox(height: tokens.space.s2),
                _GarageLinkRow(
                  icon: Icons.qr_code_scanner,
                  label: s.sharedWithMeJoin,
                  onTap: () => context.push(AppRoutes.vehicleShareJoin),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: vehicles.maybeWhen(
        data: (_) => personal
            ? _GarageBottomBar(
                canAddVehicle: canAddVehicle,
                limitMessage: canAddVehicle
                    ? null
                    : gate!.vehicleBlockMessage(s),
                onAdd: () => canAddVehicle
                    ? _openAddVehicle(context, ref)
                    : context.push(AppRoutes.pricing),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  List<Vehicle> _activeFirst(List<Vehicle> items, String? activeId) {
    final ordered = [...items];
    ordered.sort((a, b) {
      final aRank = a.id == activeId ? 0 : 1;
      final bRank = b.id == activeId ? 0 : 1;
      return aRank.compareTo(bRank);
    });
    return ordered;
  }
}

class _GarageEmpty extends StatelessWidget {
  const _GarageEmpty();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DcoLayout.sectionGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.background.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border.divider),
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: 40,
                color: tokens.icon.inactive,
              ),
            ),
            SizedBox(height: tokens.space.s5),
            Text(
              s.garageEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: tokens.space.s2),
            Text(
              s.garageEmptyBody,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.text.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarageLinkRow extends StatelessWidget {
  const _GarageLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space.s4,
            vertical: tokens.space.s3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(color: tokens.border.divider),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: tokens.icon.inactive),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: tokens.text.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _GarageBottomBar extends StatelessWidget {
  const _GarageBottomBar({
    required this.canAddVehicle,
    required this.limitMessage,
    required this.onAdd,
  });

  final bool canAddVehicle;
  final String? limitMessage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.background.primary,
        border: Border(top: BorderSide(color: tokens.border.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DcoLayout.screenPadding,
            DcoLayout.rowGap,
            DcoLayout.screenPadding,
            0,
          ),
          child: canAddVehicle
              ? DcoButton(
                  label: s.garageRegisterTooltip,
                  icon: Icons.add,
                  onPressed: onAdd,
                )
              : Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space.s3,
                    vertical: tokens.space.s2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.status.infoBg,
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: tokens.status.infoFg,
                      ),
                      SizedBox(width: tokens.space.s2),
                      Expanded(
                        child: Text(
                          limitMessage ?? '',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.status.infoFg),
                        ),
                      ),
                      TextButton(
                        onPressed: onAdd,
                        child: Text(s.pricingViewPlans),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

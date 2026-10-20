import 'dart:async';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/gating/gate_messages.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
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
  const GarageHomeScreen({super.key});

  /// Entry-point gate (§8.3 / §2): over-cap users never reach the form —
  /// the "+" is hidden and the add card degrades to the upsell caption.
  /// A null gate (hydrating) still navigates: the form's save re-checks
  /// and denies (deny-by-default lives at the create itself).
  void _openAddVehicle(BuildContext context, WidgetRef ref) {
    final gate = ref.read(featureGateProvider);
    if (gate != null && !gate.canCreateVehicle) {
      final s = AppLocalizations.of(context)!;
      unawaited(
        showDcoErrorDialog(
          context,
          title: s.planLimitTitle,
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
      appBar: AppBar(
        title: Text(s.garageMyGarage),
        actions: [
          if (canAddVehicle)
            IconButton(
              tooltip: s.garageRegisterTooltip,
              onPressed: () => _openAddVehicle(context, ref),
              icon: Icon(Icons.add, color: tokens.icon.active),
            ),
        ],
      ),
      body: vehicles.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) =>
            DcoEmptyState(title: s.garageLoadError, body: '$error'),
        data: (items) {
          if (items.isEmpty) {
            return DcoEmptyState(
              title: s.garageEmptyTitle,
              body: s.garageEmptyBody,
              actionLabel: s.garageRegisterTooltip,
              onAction: canAddVehicle
                  ? () => _openAddVehicle(context, ref)
                  : null,
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
              ),
              if (personal) ...[
                SizedBox(height: tokens.space.s3),
                Material(
                  color: tokens.background.card,
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.sharedWithMe),
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space.s4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: tokens.icon.inactive,
                          ),
                          SizedBox(width: tokens.space.s3),
                          Expanded(
                            child: Text(
                              s.drawerSharedWithMe,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: tokens.icon.inactive,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.s2),
                Material(
                  color: tokens.background.card,
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.vehicleShareJoin),
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space.s4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            color: tokens.icon.inactive,
                          ),
                          SizedBox(width: tokens.space.s3),
                          Expanded(
                            child: Text(
                              s.sharedWithMeJoin,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: tokens.icon.inactive,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.s3),
                Material(
                  color: tokens.background.card,
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                  child: InkWell(
                    onTap: canAddVehicle
                        ? () => _openAddVehicle(context, ref)
                        : null,
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space.s4),
                      child: Column(
                        children: [
                          Text(
                            s.garageAddCardTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: tokens.text.accent),
                          ),
                          SizedBox(height: tokens.space.s2),
                          Text(
                            canAddVehicle
                                ? s.garageAddCardSubtitle
                                : gate!.vehicleBlockMessage(s),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

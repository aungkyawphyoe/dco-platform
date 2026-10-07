import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../core/widgets/dco_error_dialog.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../features/garage/providers.dart';
import '../../domain/entities/vehicle_share.dart';
import '../../providers.dart';
import '../widgets/share_access_level.dart';

/// Vehicles shared *with* the signed-in user (`GET /v1/vehicles/shared`).
class SharedVehiclesScreen extends ConsumerWidget {
  const SharedVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final sharedAsync = ref.watch(sharedVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.sharedWithMeTitle),
        actions: [
          IconButton(
            tooltip: s.sharedWithMeJoin,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push(AppRoutes.vehicleShareJoin),
          ),
        ],
      ),
      body: sharedAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(sharedVehiclesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return DcoEmptyState(
              title: s.sharedWithMeEmpty,
              body: s.sharedWithMeEmptyBody,
              actionLabel: s.sharedWithMeJoin,
              onAction: () => context.push(AppRoutes.vehicleShareJoin),
            );
          }
          return RefreshIndicator(
            color: tokens.text.accent,
            onRefresh: () async => ref.invalidate(sharedVehiclesProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(tokens.space.s4),
              itemCount: items.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.space.s2),
              itemBuilder: (context, index) => _Tile(vehicle: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.vehicle});

  final SharedVehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final owner = vehicle.ownerLabel;
    final activeVehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final isActive = activeVehicle?.id == vehicle.id;

    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius.md),
      onTap: () => context.push(AppRoutes.vehicleDetail(vehicle.id)),
      child: Container(
        padding: EdgeInsets.all(tokens.space.s1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.tokens.radius.lg),
          boxShadow: context.tokens.shadows.card,
        ),
        child: Material(
          color: context.tokens.background.card,
          borderRadius: BorderRadius.circular(context.tokens.radius.lg),
          child: Padding(
            padding: EdgeInsets.all(context.tokens.space.s3),
            child: Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  color: tokens.icon.inactive,
                ),
                SizedBox(width: tokens.space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vehicle.displayName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: tokens.text.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: tokens.space.s2),
                          ShareAccessBadge(accessLevel: vehicle.accessLevel),
                        ],
                      ),
                      SizedBox(height: tokens.space.s1),
                      Text(
                        vehicle.licensePlate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.secondary,
                          fontFamily: 'IBM Plex Mono',
                        ),
                      ),
                      SizedBox(height: tokens.space.s1),
                      Text(
                        owner.isEmpty
                            ? s.shareOwnerLabel
                            : '${s.shareOwnerLabel}: $owner',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isActive)
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(setActiveVehicleProvider)(vehicle.id);
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
                      if (context.mounted) context.go(AppRoutes.dashboard);
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space.s2,
                      ),
                    ),
                    child: Text(
                      s.vehicleSetActive,
                      style: TextStyle(color: tokens.text.link, fontSize: 12),
                    ),
                  )
                else
                  _Badge(
                    label: s.active,
                    color: tokens.status.infoFg,
                    background: tokens.status.infoBg,
                  ),
                Icon(Icons.chevron_right, color: tokens.icon.inactive),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

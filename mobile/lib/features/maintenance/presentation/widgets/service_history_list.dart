import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/plan_item_tile.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The maintenance history list for one vehicle, shared by the standalone
/// Service History screen and the vehicle detail Maintenance tab.
class ServiceHistoryList extends ConsumerWidget {
  const ServiceHistoryList({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final history = ref.watch(maintenanceHistoryForVehicleProvider(vehicleId));
    final lengthUnit = ref.watch(lengthUnitProvider);
    final currency = ref.watch(currencyProvider).code;

    return history.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: tokens.text.accent),
      ),
      error: (error, _) =>
          DcoEmptyState(title: s.serviceHistoryLoadError, body: '$error'),
      data: (records) {
        if (records.isEmpty) {
          return DcoEmptyState(
            title: s.serviceHistoryEmptyTitle,
            body: s.serviceHistoryEmptyBody,
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            top: tokens.space.s3,
            bottom: tokens.space.s5,
          ),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return HistoryTile(
              record: record,
              lengthUnit: lengthUnit,
              currency: currency,
              onTap: () => context.push(AppRoutes.serviceDetail(record.id)),
            );
          },
        );
      },
    );
  }
}

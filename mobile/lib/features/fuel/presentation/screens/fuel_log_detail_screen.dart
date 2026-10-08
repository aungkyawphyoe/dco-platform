import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_access.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/vehicle_sharing/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FuelLogDetailScreen extends ConsumerWidget {
  const FuelLogDetailScreen({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final currency = ref.watch(currencyProvider).code;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final currentUserId = ref.watch(currentUserIdProvider);
    final logAsync = ref.watch(fuelLogDetailProvider(logId));
    final log = logAsync.valueOrNull;

    final canEdit =
        log != null &&
        vehicle != null &&
        VehicleAccess.of(vehicle, currentUserId).canEditRecord(log.userId);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.fuelLogDetailTitle),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: s.edit,
              icon: Icon(Icons.edit_outlined, color: tokens.icon.inactive),
              onPressed: () async {
                await context.push(AppRoutes.fuelLogEdit(logId));
                if (context.mounted) ref.invalidate(fuelLogDetailProvider(logId));
              },
            ),
        ],
      ),
      body: logAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
        error: (error, stackTrace) => DcoEmptyState(
          title: s.fuelLogDetailNotFound,
          body: s.fuelLogDetailNotFoundBody,
        ),
        data: (log) {
          if (log == null) {
            return DcoEmptyState(
              title: s.fuelLogDetailNotFound,
              body: s.fuelLogDetailNotFoundBody,
            );
          }
          final nameAsync = ref.watch(userNameProvider(log.userId));
          return ListView(
            padding: EdgeInsets.all(tokens.space.s5),
            children: [
              Text(log.fuelTypeName, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.space.s2),
              Text(
                DateFormat.yMMMd().format(log.loggedOn),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.secondary,
                ),
              ),
              SizedBox(height: tokens.space.s5),
              if (log.odometer != null)
                _kv(
                  context,
                  s.serviceDetailMileage,
                  MileageFormat.labeled(log.odometer!, lengthUnit),
                ),
              _kv(context, s.fuelLogDetailAmount, log.amountLabel),
              _kv(context, s.fuelLogDetailCost, MoneyFormat.labeled(log.cost, currency)),
              _kv(context, s.loggedBy, nameAsync.valueOrNull ?? '—'),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: tokens.space.s1),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

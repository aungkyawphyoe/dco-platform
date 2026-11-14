import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/units/mileage_format.dart';
import '../../../../core/units/money_format.dart';
import '../../../../core/widgets/log_success_screen.dart';
import '../../../../generated/app_localizations.dart';
import '../../../settings/providers.dart';
import '../../domain/entities/fuel_log.dart';

class FuelLogSuccessScreen extends ConsumerWidget {
  const FuelLogSuccessScreen({super.key, required this.log});

  final FuelLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final charge = log.kind == FuelLogKind.charge;
    return LogSuccessScreen(
      title: charge ? s.fuelLogAddCharge : s.fuelLogAddRefuel,
      heading: charge ? s.chargeSuccessTitle : s.refuelSuccessTitle,
      details: [
        (
          label: s.registerServiceDate,
          value: DateFormat.yMMMd(s.localeName).format(log.loggedOn),
        ),
        (label: s.fuelLogFormTypeSheetTitle, value: log.fuelTypeName),
        (label: s.fuelLogDetailAmount, value: log.amountLabel),
        (
          label: s.fuelLogDetailCost,
          value: MoneyFormat.labeled(log.cost, log.currency),
        ),
        if (log.odometer != null)
          (
            label: s.fuelLogFormOdometer,
            value: MileageFormat.labeled(
              log.odometer!,
              ref.watch(lengthUnitProvider),
            ),
          ),
      ],
    );
  }
}

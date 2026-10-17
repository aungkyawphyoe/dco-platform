import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Driver Expenses tab: fuel logs for the assigned vehicle, read-only.
///
/// Drivers log fuel only (no expense categories) — the personal Expenses
/// category picker is hidden. "Refuel" is the write action, reached from
/// Garage Quick Actions or this screen's empty state.
class DriverExpensesScreen extends ConsumerWidget {
  const DriverExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final myVehicle = ref.watch(driverMyVehicleProvider).valueOrNull;

    if (myVehicle?.hasAssignedVehicle != true) {
      return Scaffold(
        appBar: AppBar(title: Text(s.expensesTitle)),
        body: DcoEmptyState(
          title: s.driverNoVehicleTitle,
          body: s.driverNoVehicleBody,
        ),
      );
    }

    final vehicleId = myVehicle!.vehicle!.id;
    final logsAsync = ref.watch(driverFuelLogsProvider(vehicleId));
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(title: Text(s.expensesTitle)),
      body: logsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
        error: (error, stack) => DcoEmptyState(
          title: s.driverFuelNoLogsTitle,
          body: s.driverFuelNoLogsBody,
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: DcoEmptyState(
                title: s.driverFuelNoLogsTitle,
                body: s.driverFuelNoLogsBody,
                actionLabel: s.driverQuickRefuel,
                onAction: () => context.push(AppRoutes.driverFuelLog),
              ),
            );
          }
          final total = logs.fold<double>(0, (sum, log) => sum + log.cost);
          return ListView(
            padding: EdgeInsets.all(tokens.space.s4),
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(tokens.space.s4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.driverFuelTotalLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.text.secondary,
                        ),
                      ),
                      Text(
                        MoneyFormat.labeled(total, currency),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: tokens.text.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader(s.driverFuelLogsLabel),
              ...logs.map(
                (log) => Card(
                  margin: EdgeInsets.only(bottom: tokens.space.s2),
                  child: ListTile(
                    leading: Icon(
                      Icons.local_gas_station_outlined,
                      color: tokens.icon.inactive,
                    ),
                    title: Text(log.fuelTypeName),
                    subtitle: Text(
                      [
                        DateFormat.yMMMd().format(log.loggedOn),
                        log.amountLabel,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.caption,
                      ),
                    ),
                    trailing: Text(
                      MoneyFormat.labeled(log.cost, currency),
                      style: GoogleFonts.ibmPlexMono(
                        fontWeight: FontWeight.w500,
                        color: tokens.text.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

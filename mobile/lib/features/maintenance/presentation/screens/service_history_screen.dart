import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/service_history_list.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServiceHistoryScreen extends ConsumerWidget {
  const ServiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(s.serviceHistoryTitle)),
      body: vehicle == null
          ? DcoEmptyState(
              title: s.maintenanceNoActiveVehicle,
              body: s.serviceHistoryNoActiveVehicleBody,
            )
          : ServiceHistoryList(vehicleId: vehicle.id),
    );
  }
}

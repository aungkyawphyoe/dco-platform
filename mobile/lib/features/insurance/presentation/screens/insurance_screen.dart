import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(s.insuranceTitle)),
      body: DcoEmptyState(
        title: active == null ? s.insuranceNoActiveVehicle : s.insuranceComingLater,
        body: active == null
            ? s.insuranceNoActiveVehicleBody
            : s.insuranceEmptyBody(active.displayName),
      ),
    );
  }
}

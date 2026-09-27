import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Log mileage: start / end shift plus recent shift history.
class DriverShiftScreen extends ConsumerStatefulWidget {
  const DriverShiftScreen({super.key});

  @override
  ConsumerState<DriverShiftScreen> createState() =>
      _DriverShiftScreenState();
}

class _DriverShiftScreenState extends ConsumerState<DriverShiftScreen> {
  final _odometer = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _odometer.dispose();
    super.dispose();
  }

  Future<void> _start(String orgId, String vehicleId) async {
    final s = AppLocalizations.of(context)!;
    final value = int.tryParse(_odometer.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.required)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(fleetRepositoryProvider)
          .startShift(orgId, vehicleId: vehicleId, startOdometerKm: value);
      ref.invalidate(shiftMileageProvider(orgId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.driverShiftStarted)));
      _odometer.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _end(String orgId, String shiftId) async {
    final s = AppLocalizations.of(context)!;
    final value = int.tryParse(_odometer.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.required)));
      return;
    }
    setState(() => _saving = true);
    try {
      final shift = await ref
          .read(fleetRepositoryProvider)
          .endShift(orgId, shiftId, endOdometerKm: value);
      ref.invalidate(shiftMileageProvider(orgId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.driverShiftEnded(shift.kmDriven ?? 0)),
        ),
      );
      _odometer.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;
    final userId = ref.watch(currentUserIdProvider);

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverShiftTitle)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    final orgId = orgCtx.id;
    final myVehicle = ref.watch(driverMyVehicleProvider).valueOrNull;
    final shiftsAsync = ref.watch(shiftMileageProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: Text(s.driverShiftTitle)),
      body: shiftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DcoEmptyState(
          title: s.error,
          body: error.toString(),
          actionLabel: s.retry,
          onAction: () => ref.invalidate(shiftMileageProvider(orgId)),
        ),
        data: (shifts) {
          final mine = [
            for (final shift in shifts)
              if (userId == null || shift.driverId == userId) shift,
          ];
          final active = mine.where((shift) => shift.isActive).firstOrNull;

          if (myVehicle?.hasAssignedVehicle != true) {
            return DcoEmptyState(
              title: s.driverNoVehicleTitle,
              body: s.driverNoVehicleBody,
            );
          }
          final vehicle = myVehicle!.vehicle!;

          return ListView(
            padding: EdgeInsets.all(tokens.space.s3),
            children: [
              if (active != null)
                Card(
                  color: tokens.status.warningBg,
                  child: Padding(
                    padding: EdgeInsets.all(tokens.space.s3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle,
                              color: tokens.status.warningFg,
                            ),
                            SizedBox(width: tokens.space.s2),
                            Text(
                              s.driverShiftActive,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        SizedBox(height: tokens.space.s2),
                        Text(
                          '${s.driverShiftStartOdo}: ${active.startOdometerKm} · '
                          '${active.startAt ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: tokens.space.s3),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(tokens.space.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active == null
                            ? s.driverShiftStartTitle
                            : s.driverShiftEndTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: tokens.space.s2),
                      DcoTextField(
                        controller: _odometer,
                        label: active == null
                            ? s.driverShiftStartOdo
                            : s.driverShiftEndOdo,
                        hint: vehicle.displayName,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                      ),
                      SizedBox(height: tokens.space.s3),
                      DcoButton(
                        label: active == null
                            ? s.driverShiftStartTitle
                            : s.driverShiftEndTitle,
                        loading: _saving,
                        onPressed: active == null
                            ? () => _start(orgId, vehicle.id)
                            : () => _end(orgId, active.id),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space.s4),
              Text(
                s.driverShiftHistory,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.text.secondary,
                ),
              ),
              SizedBox(height: tokens.space.s2),
              if (mine.isEmpty)
                Text(
                  s.driverShiftEmpty,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.text.caption),
                ),
              for (final shift in mine)
                Card(
                  margin: EdgeInsets.only(bottom: tokens.space.s2),
                  child: ListTile(
                    leading: Icon(
                      Icons.route_outlined,
                      color: tokens.icon.inactive,
                    ),
                    title: Text(
                      shift.endAt == null
                          ? s.driverShiftActive
                          : s.driverShiftKmDriven(shift.kmDriven ?? 0),
                    ),
                    subtitle: Text(
                      '${shift.startOdometerKm} → '
                      '${shift.endOdometerKm ?? '…'} · '
                      '${shift.startAt ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.caption,
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

import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Driver fuel log against the organization (online-only).
class DriverFuelLogScreen extends ConsumerStatefulWidget {
  const DriverFuelLogScreen({super.key});

  @override
  ConsumerState<DriverFuelLogScreen> createState() =>
      _DriverFuelLogScreenState();
}

class _DriverFuelLogScreenState extends ConsumerState<DriverFuelLogScreen> {
  final _amount = TextEditingController();
  final _cost = TextEditingController();
  final _odometer = TextEditingController();

  final _errors = <String, String?>{};
  String? _fuelTypeId;
  DateTime _loggedOn = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _cost.dispose();
    _odometer.dispose();
    super.dispose();
  }

  Future<void> _submit(String orgId, String vehicleId) async {
    final s = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amount.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    final odometer = int.tryParse(_odometer.text.trim());
    setState(() {
      _errors
        ..['amount'] = (amount == null || amount <= 0) ? s.required : null
        ..['cost'] = (cost == null || cost < 0) ? s.required : null
        ..['odometer'] = (odometer == null || odometer < 0)
            ? s.required
            : null
        ..['fuelType'] = _fuelTypeId == null ? s.required : null;
    });
    if (_errors.values.any((error) => error != null)) return;

    setState(() => _saving = true);
    try {
      await ref.read(fleetRepositoryProvider).logOrgFuel(
            orgId,
            vehicleId: vehicleId,
            fuelTypeId: _fuelTypeId!,
            loggedOn: DateFormat('yyyy-MM-dd').format(_loggedOn),
            amount: amount!,
            cost: cost!,
            odometerKm: odometer!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.driverFuelLogged)));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;
    final myVehicle = ref.watch(driverMyVehicleProvider).valueOrNull;
    final fuelTypes = ref.watch(driverFuelCatalogProvider).valueOrNull ?? const [];
    final currency = ref.watch(currencyProvider).code;

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverFuelTitle)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    if (myVehicle?.hasAssignedVehicle != true) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverFuelTitle)),
        body: DcoEmptyState(
          title: s.driverNoVehicleTitle,
          body: s.driverNoVehicleBody,
        ),
      );
    }
    final vehicle = myVehicle!.vehicle!;

    return Scaffold(
      appBar: AppBar(title: Text(s.driverFuelTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s3),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: tokens.space.s3),
            child: Text(
              vehicle.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (fuelTypes.isEmpty)
            Text(
              s.driverFuelNoTypes,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _fuelTypeId,
              decoration: InputDecoration(labelText: s.vehicleFuelTypeLabel),
              items: [
                for (final type in fuelTypes)
                  DropdownMenuItem(
                    value: type.id,
                    child: Text('${type.name} (${type.unit})'),
                  ),
              ],
              onChanged: (v) => setState(() => _fuelTypeId = v),
            ),
            if (_errors['fuelType'] != null)
              Padding(
                padding: EdgeInsets.only(top: tokens.space.s1),
                child: Text(
                  _errors['fuelType']!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.status.dangerFg),
                ),
              ),
          ],
          SizedBox(height: tokens.space.s2),
          Row(
            children: [
              Expanded(
                child: DcoTextField(
                  controller: _amount,
                  label: s.driverFuelAmount,
                  errorText: _errors['amount'],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: DcoTextField(
                  controller: _cost,
                  label: s.driverFuelCost,
                  errorText: _errors['cost'],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 12),
                    child: Text(
                      currency,
                      style: TextStyle(color: tokens.text.caption),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space.s2),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: tokens.icon.inactive,
              ),
              title: Text(s.driverFuelDate),
              subtitle: Text(DateFormat.yMMMd().format(_loggedOn)),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _loggedOn,
                  firstDate: DateTime(1900),
                  lastDate: now,
                );
                if (picked != null) setState(() => _loggedOn = picked);
              },
            ),
          ),
          SizedBox(height: tokens.space.s2),
          DcoTextField(
            controller: _odometer,
            label: s.fleetWoOdometerKm,
            errorText: _errors['odometer'],
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: tokens.space.s5),
          DcoButton(
            label: s.save,
            loading: _saving,
            onPressed: fuelTypes.isEmpty
                ? null
                : () => _submit(orgCtx.id, vehicle.id),
          ),
        ],
      ),
    );
  }
}

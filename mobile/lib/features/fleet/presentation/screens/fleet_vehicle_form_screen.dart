import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_validators.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// Add an organization vehicle (admin / manager).
class FleetVehicleFormScreen extends ConsumerStatefulWidget {
  const FleetVehicleFormScreen({super.key});

  @override
  ConsumerState<FleetVehicleFormScreen> createState() =>
      _FleetVehicleFormScreenState();
}

class _FleetVehicleFormScreenState
    extends ConsumerState<FleetVehicleFormScreen> {
  final _name = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  final _vin = TextEditingController();
  final _mileage = TextEditingController();
  final _revenueLabel = TextEditingController();

  final _errors = <String, String?>{};
  String _fuelType = 'petrol';
  String _lifecycleTemplate = 'showroom';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    _vin.dispose();
    _mileage.dispose();
    _revenueLabel.dispose();
    super.dispose();
  }

  OrgVehicleDraft? _draftOrNull() {
    setState(() {
      _errors
        ..['name'] = VehicleValidators.name(_name.text)
        ..['make'] = VehicleValidators.make(_make.text)
        ..['model'] = VehicleValidators.model(_model.text)
        ..['year'] = VehicleValidators.year(_year.text)
        ..['plate'] = VehicleValidators.licensePlate(_plate.text)
        ..['mileage'] = VehicleValidators.mileage(_mileage.text)
        ..['vin'] = VehicleValidators.vin(_vin.text);
    });
    if (_errors.values.any((error) => error != null)) return null;
    return OrgVehicleDraft(
      id: const Uuid().v4(),
      name: _name.text.trim(),
      make: _make.text.trim(),
      model: _model.text.trim(),
      year: VehicleValidators.parseYear(_year.text)!,
      licensePlate: _plate.text.trim(),
      vin: _vin.text.trim(),
      fuelType: _fuelType,
      mileage: VehicleValidators.parseMileage(_mileage.text)!.round(),
      lifecycleTemplate: _lifecycleTemplate,
      revenueLabel: _revenueLabel.text.trim().isEmpty
          ? null
          : _revenueLabel.text.trim(),
    );
  }

  Future<void> _submit() async {
    final s = AppLocalizations.of(context)!;
    final draft = _draftOrNull();
    if (draft == null) return;
    final orgCtx = ref.read(entitlementsProvider).valueOrNull?.organization;
    if (orgCtx == null) return;

    setState(() => _saving = true);
    try {
      final vehicle = await ref
          .read(fleetRepositoryProvider)
          .addVehicle(orgCtx.id, draft);
      ref.invalidate(orgVehiclesProvider(orgCtx.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fleetVehicleAdded)));
      context.pop();
      context.push(AppRoutes.fleetVehicleDetail(vehicle.id));
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

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetVehicleFormTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s3),
        children: [
          DcoTextField(
            controller: _name,
            label: s.vehicleNameLabel,
            errorText: _errors['name'],
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space.s2),
          Row(
            children: [
              Expanded(
                child: DcoTextField(
                  controller: _make,
                  label: s.vehicleMakeLabel,
                  errorText: _errors['make'],
                  textInputAction: TextInputAction.next,
                ),
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: DcoTextField(
                  controller: _model,
                  label: s.vehicleModelLabel,
                  errorText: _errors['model'],
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space.s2),
          Row(
            children: [
              Expanded(
                child: DcoTextField(
                  controller: _year,
                  label: s.vehicleYearLabel,
                  errorText: _errors['year'],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: DcoTextField(
                  controller: _mileage,
                  label: s.vehicleMileageLabel,
                  errorText: _errors['mileage'],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space.s2),
          DcoTextField(
            controller: _plate,
            label: s.vehiclePlateLabel,
            errorText: _errors['plate'],
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space.s2),
          DcoTextField(
            controller: _vin,
            label: s.vehicleVinLabel,
            errorText: _errors['vin'],
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space.s3),
          DropdownButtonFormField<String>(
            initialValue: _fuelType,
            decoration: InputDecoration(labelText: s.vehicleFuelTypeLabel),
            items: const [
              DropdownMenuItem(value: 'petrol', child: Text('petrol')),
              DropdownMenuItem(value: 'electric', child: Text('electric')),
              DropdownMenuItem(
                value: 'hybrid_plugin',
                child: Text('hybrid_plugin'),
              ),
            ],
            onChanged: (v) => setState(() => _fuelType = v ?? 'petrol'),
          ),
          SizedBox(height: tokens.space.s3),
          DropdownButtonFormField<String>(
            initialValue: _lifecycleTemplate,
            decoration: InputDecoration(labelText: s.fleetVehicleLifecycle),
            items: [
              for (final template in const [
                'showroom',
                'taxi_fleet',
                'rental',
                'commercial',
              ])
                DropdownMenuItem(
                  value: template,
                  child: Text(lifecycleLabel(s, template)),
                ),
            ],
            onChanged: (v) =>
                setState(() => _lifecycleTemplate = v ?? 'showroom'),
          ),
          SizedBox(height: tokens.space.s3),
          DcoTextField(
            controller: _revenueLabel,
            label: s.fleetVehicleRevenueLabel,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: tokens.space.s5),
          DcoButton(label: s.save, loading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}

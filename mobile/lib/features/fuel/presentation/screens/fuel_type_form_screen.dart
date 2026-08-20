import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';
import 'package:dco_mobile/features/fuel/domain/fuel_failure.dart';
import 'package:dco_mobile/features/fuel/domain/fuel_validators.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FuelTypeFormScreen extends ConsumerStatefulWidget {
  const FuelTypeFormScreen({super.key, this.fuelTypeId, this.initialKind});

  final String? fuelTypeId;
  final FuelCatalogKind? initialKind;

  bool get isEditing => fuelTypeId != null;

  @override
  ConsumerState<FuelTypeFormScreen> createState() => _FuelTypeFormScreenState();
}

class _FuelTypeFormScreenState extends ConsumerState<FuelTypeFormScreen> {
  final _name = TextEditingController();
  final _errors = <String, String?>{};

  FuelCatalogKind _kind = FuelCatalogKind.liquid;
  String _unit = FuelCatalogKind.liquid.defaultUnit;
  String? _formError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind ?? FuelCatalogKind.liquid;
    _unit = _kind.defaultUnit;
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.fuelTypeId == null) {
      setState(() => _loading = false);
      return;
    }
    final type = await ref.read(fuelRepositoryProvider).getFuelType(widget.fuelTypeId!);
    if (!mounted) return;
    if (type != null) {
      _name.text = type.name;
      _kind = type.kind;
      _unit = type.unit;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  FuelCatalogTypeDraft? _draftOrNull() {
    setState(() {
      _errors
        ..['name'] = FuelTypeValidators.name(_name.text)
        ..['unit'] = FuelTypeValidators.unit(_kind, _unit);
      _formError = null;
    });
    if (_errors.values.any((error) => error != null)) return null;
    return FuelCatalogTypeDraft(name: _name.text, kind: _kind, unit: _unit);
  }

  Future<void> _save() async {
    final draft = _draftOrNull();
    if (draft == null) return;
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(fuelRepositoryProvider);
      if (widget.isEditing) {
        await repo.updateFuelType(userId: vehicle.userId, fuelTypeId: widget.fuelTypeId!, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.fuelTypeUpdated);
      } else {
        await repo.addFuelType(userId: vehicle.userId, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.fuelTypeAdded);
      }
      if (mounted) context.pop();
    } on FuelFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectKind(FuelCatalogKind kind) {
    setState(() {
      _kind = kind;
      if (!kind.units.contains(_unit)) {
        _unit = kind.defaultUnit;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit Fuel Type' : 'Add Fuel Type')),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Fuel Type' : 'Add Fuel Type')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                DcoTextField(
                  key: const Key('fuel-type-name'),
                  label: 'Name *',
                  controller: _name,
                  hint: _kind == FuelCatalogKind.electric ? 'Electricity' : 'Petrol',
                  errorText: _errors['name'],
                  maxLength: FuelTypeValidators.maxNameLength,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _errors['name'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                Text('Kind *', style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s2),
                Wrap(
                  spacing: tokens.space.s2,
                  children: FuelCatalogKind.values.map((kind) {
                    final selected = _kind == kind;
                    return ChoiceChip(
                      label: Text(kind.label),
                      selected: selected,
                      onSelected: (_) => _selectKind(kind),
                      showCheckmark: false,
                      selectedColor: tokens.text.accent,
                      labelStyle: TextStyle(
                        color: selected ? tokens.text.onAccent : tokens.text.primary,
                      ),
                      backgroundColor: tokens.background.input,
                      side: BorderSide(color: selected ? tokens.border.highlight : tokens.border.defaultColor),
                    );
                  }).toList(),
                ),
                SizedBox(height: tokens.space.s4),
                Text('Unit *', style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s2),
                Wrap(
                  spacing: tokens.space.s2,
                  children: _kind.units.map((unit) {
                    final selected = _unit == unit;
                    return ChoiceChip(
                      label: Text(unit),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _unit = unit;
                        _errors['unit'] = null;
                      }),
                      showCheckmark: false,
                      selectedColor: tokens.text.accent,
                      labelStyle: TextStyle(
                        color: selected ? tokens.text.onAccent : tokens.text.primary,
                      ),
                      backgroundColor: tokens.background.input,
                      side: BorderSide(color: selected ? tokens.border.highlight : tokens.border.defaultColor),
                    );
                  }).toList(),
                ),
                if (_errors['unit'] != null)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.space.s2),
                    child: Text(_errors['unit']!, style: TextStyle(color: tokens.status.dangerFg)),
                  ),
                if (_formError != null) ...[
                  SizedBox(height: tokens.space.s4),
                  Text(_formError!, style: TextStyle(color: tokens.status.dangerFg)),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(tokens.space.s5, tokens.space.s3, tokens.space.s5, tokens.space.s5),
            child: Row(
              children: [
                Expanded(
                  child: DcoButton(
                    label: 'Cancel',
                    variant: DcoButtonVariant.secondary,
                    onPressed: () => context.pop(),
                  ),
                ),
                SizedBox(width: tokens.space.s3),
                Expanded(
                  child: DcoButton(
                    key: const Key('fuel-type-save'),
                    label: 'Save',
                    onPressed: _save,
                    loading: _saving,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

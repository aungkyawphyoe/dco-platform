import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_failure.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_validators.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicleId});

  final String? vehicleId;

  bool get isEditing => vehicleId != null;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _name = TextEditingController();
  final _make = TextEditingController();
  final _year = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _mileage = TextEditingController();
  final _vin = TextEditingController();
  final _color = TextEditingController();
  final _nickname = TextEditingController();
  final _purchaseDate = TextEditingController();

  final _errors = <String, String?>{};
  FuelType? _fuelType;
  DateTime? _purchaseDateValue;
  String? _photoPath;
  String? _formError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.vehicleId == null) {
      setState(() => _loading = false);
      return;
    }
    final vehicle = await ref.read(vehicleRepositoryProvider).getById(widget.vehicleId!);
    if (!mounted) return;
    if (vehicle != null) {
      _name.text = vehicle.name;
      _make.text = vehicle.make;
      _year.text = '${vehicle.year}';
      _model.text = vehicle.model;
      _plate.text = vehicle.licensePlate;
      _mileage.text = MileageFormat.input(vehicle.mileage, ref.read(lengthUnitProvider));
      _vin.text = vehicle.vin ?? '';
      _color.text = vehicle.color ?? '';
      _nickname.text = vehicle.nickname ?? '';
      _fuelType = vehicle.fuelType;
      _purchaseDateValue = vehicle.purchaseDate;
      if (vehicle.purchaseDate != null) {
        _purchaseDate.text = DateFormat.yMMMd().format(vehicle.purchaseDate!);
      }
      _photoPath = vehicle.photoLocalPath;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _make.dispose();
    _year.dispose();
    _model.dispose();
    _plate.dispose();
    _mileage.dispose();
    _vin.dispose();
    _color.dispose();
    _nickname.dispose();
    _purchaseDate.dispose();
    super.dispose();
  }

  VehicleDraft? _draftOrNull() {
    setState(() {
      _errors
        ..['name'] = VehicleValidators.name(_name.text)
        ..['make'] = VehicleValidators.make(_make.text)
        ..['year'] = VehicleValidators.year(_year.text)
        ..['model'] = VehicleValidators.model(_model.text)
        ..['plate'] = VehicleValidators.licensePlate(_plate.text)
        ..['mileage'] = VehicleValidators.mileage(_mileage.text)
        ..['vin'] = VehicleValidators.vin(_vin.text)
        ..['fuel'] = _fuelType == null ? 'Fuel type is required' : null;
      _formError = null;
    });
    if (_errors.values.any((error) => error != null) || _fuelType == null) return null;
    final unit = ref.read(lengthUnitProvider);
    return VehicleDraft(
      name: _name.text,
      make: _make.text,
      model: _model.text,
      year: VehicleValidators.parseYear(_year.text)!,
      licensePlate: _plate.text,
      fuelType: _fuelType!,
      mileage: unit.toStorage(VehicleValidators.parseMileage(_mileage.text)!),
      mileageUnit: MileageUnit.mi,
      nickname: _nickname.text,
      vin: _vin.text,
      color: _color.text,
      purchaseDate: _purchaseDateValue,
      photoLocalPath: _photoPath,
    );
  }

  Future<void> _save() async {
    final draft = _draftOrNull();
    if (draft == null) return;
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(vehicleRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(userId: userId, vehicleId: widget.vehicleId!, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.vehicleUpdated);
      } else {
        await repo.add(userId: userId, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.vehicleAdded);
      }
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } on VehicleFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDateValue ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _purchaseDateValue = picked;
      _purchaseDate.text = DateFormat.yMMMd().format(picked);
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final dest = File('${directory.path}/vehicles/${const Uuid().v4()}.jpg');
    await dest.parent.create(recursive: true);
    await File(picked.path).copy(dest.path);
    if (mounted) setState(() => _photoPath = dest.path);
  }

  Future<void> _archive() async {
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user.id;
    if (userId == null || widget.vehicleId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archive this vehicle?'),
          content: const Text('Records stay attached and hidden. This does not permanently delete them.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref.read(vehicleRepositoryProvider).archive(userId: userId, vehicleId: widget.vehicleId!);
    ref.read(analyticsProvider).track(AnalyticsEvent.vehicleDeleted);
    if (mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit Vehicle' : 'Register Vehicle')),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Vehicle' : 'Register Vehicle')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                _PhotoPicker(path: _photoPath, onTap: _pickPhoto),
                SizedBox(height: tokens.space.s5),
                Text('Required Information', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('vehicle-name'),
                  label: 'Name *',
                  controller: _name,
                  errorText: _errors['name'],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['name'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                Row(
                  children: [
                    Expanded(
                      child: DcoTextField(
                        key: const Key('vehicle-year'),
                        label: 'Year *',
                        controller: _year,
                        errorText: _errors['year'],
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() => _errors['year'] = null),
                      ),
                    ),
                    SizedBox(width: tokens.space.s3),
                    Expanded(
                      child: DcoTextField(
                        key: const Key('vehicle-make'),
                        label: 'Make *',
                        controller: _make,
                        errorText: _errors['make'],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() => _errors['make'] = null),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('vehicle-model'),
                  label: 'Model *',
                  controller: _model,
                  errorText: _errors['model'],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['model'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('vehicle-plate'),
                  label: 'License Plate *',
                  controller: _plate,
                  errorText: _errors['plate'],
                  maxLength: 20,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['plate'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('vehicle-mileage'),
                  label: 'Mileage *',
                  controller: _mileage,
                  errorText: _errors['mileage'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 12),
                    child: Text(lengthUnit.label, style: TextStyle(color: tokens.text.caption)),
                  ),
                  onChanged: (_) => setState(() => _errors['mileage'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                Text('Fuel Type *', style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s2),
                Wrap(
                  spacing: tokens.space.s2,
                  children: FuelType.values.map((type) {
                    final selected = _fuelType == type;
                    return ChoiceChip(
                      label: Text(type.label),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _fuelType = type;
                        _errors['fuel'] = null;
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
                if (_errors['fuel'] != null)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.space.s2),
                    child: Text(_errors['fuel']!, style: TextStyle(color: tokens.status.dangerFg)),
                  ),
                SizedBox(height: tokens.space.s6),
                Text('Optional Details', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'VIN',
                  controller: _vin,
                  errorText: _errors['vin'],
                  maxLength: 17,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['vin'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                Row(
                  children: [
                    Expanded(
                      child: DcoTextField(
                        label: 'Color',
                        controller: _color,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    SizedBox(width: tokens.space.s3),
                    Expanded(
                      child: DcoTextField(
                        label: 'Nickname',
                        controller: _nickname,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'Purchase Date',
                  controller: _purchaseDate,
                  readOnly: true,
                  onTap: _pickDate,
                  suffix: Icon(Icons.calendar_today_outlined, color: tokens.icon.inactive, size: 18),
                ),
                if (_formError != null) ...[
                  SizedBox(height: tokens.space.s4),
                  Text(_formError!, style: TextStyle(color: tokens.status.dangerFg)),
                ],
                if (widget.isEditing) ...[
                  SizedBox(height: tokens.space.s6),
                  DcoButton(
                    label: 'Archive vehicle',
                    variant: DcoButtonVariant.destructive,
                    onPressed: _archive,
                  ),
                ],
                SizedBox(height: tokens.space.s7),
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
                    key: const Key('vehicle-save'),
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.path, required this.onTap});

  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: Ink(
        height: 140,
        decoration: BoxDecoration(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          border: Border.all(color: tokens.border.divider),
        ),
        child: path == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: tokens.icon.inactive),
                  SizedBox(height: tokens.space.s2),
                  Text('Add photo', style: TextStyle(color: tokens.text.caption)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radius.md),
                child: Image.file(File(path!), fit: BoxFit.cover, width: double.infinity),
              ),
      ),
    );
  }
}

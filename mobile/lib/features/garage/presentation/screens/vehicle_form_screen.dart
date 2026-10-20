import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/gating/gate_messages.dart';
import 'package:dco_mobile/core/gating/providers.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_layout.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_error_dialog.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_failure.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_validators.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
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
  bool _fuelError = false;
  bool _isOwner = false;

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
    final vehicle = await ref
        .read(vehicleRepositoryProvider)
        .getById(widget.vehicleId!);
    if (!mounted) return;
    if (vehicle != null) {
      _isOwner =
          vehicle.userId ==
          ref.read(sessionControllerProvider).valueOrNull?.user.id;
      _name.text = vehicle.name;
      _make.text = vehicle.make;
      _year.text = '${vehicle.year}';
      _model.text = vehicle.model;
      _plate.text = vehicle.licensePlate;
      _mileage.text = MileageFormat.input(
        vehicle.mileage,
        ref.read(lengthUnitProvider),
      );
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
        ..['fuel'] = null;
      _fuelError = _fuelType == null;
      _formError = null;
    });
    if (_errors.values.any((error) => error != null) || _fuelType == null) {
      return null;
    }
    final unit = ref.read(lengthUnitProvider);
    return VehicleDraft(
      name: _name.text,
      make: _make.text,
      model: _model.text,
      year: VehicleValidators.parseYear(_year.text)!,
      licensePlate: _plate.text,
      fuelType: _fuelType!,
      mileage: unit.toStorage(VehicleValidators.parseMileage(_mileage.text)!),
      mileageUnit: MileageUnit.km,
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

    // Local gate on interactive creates only — edits of existing
    // vehicles are always allowed (decision 7). Null gate = hydrating =
    // deny (§8.1).
    if (!widget.isEditing) {
      final gate = ref.read(featureGateProvider);
      if (gate == null || !gate.canCreateVehicle) {
        if (!mounted) return;
        final s = AppLocalizations.of(context)!;
        await showDcoErrorDialog(
          context,
          title: s.planLimitTitle,
          message: gate == null
              ? s.planLimitChecking
              : gate.vehicleBlockMessage(s),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(vehicleRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(
          userId: userId,
          vehicleId: widget.vehicleId!,
          draft: draft,
        );
        ref.read(analyticsProvider).track(AnalyticsEvent.vehicleUpdated);
        if (!mounted) return;
        context.go(AppRoutes.dashboard);
        return;
      }

      final previousActiveId = ref.read(activeVehicleProvider).valueOrNull?.id;
      final vehicle = await repo.add(userId: userId, draft: draft);
      ref.read(analyticsProvider).track(AnalyticsEvent.vehicleAdded);
      await ref
          .read(maintenanceRepositoryProvider)
          .ensureDefaultPlan(userId: userId, vehicle: vehicle);
      if (previousActiveId != null && previousActiveId != vehicle.id) {
        try {
          await ref.read(setActiveVehicleProvider)(vehicle.id);
          ref.read(analyticsProvider).track(AnalyticsEvent.vehicleSwitched);
        } catch (_) {}
      }
      if (!mounted) return;
      context.pushReplacement(AppRoutes.maintenancePlanRegistered);
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
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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
        final s = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(s.vehicleArchiveTitle),
          content: Text(s.vehicleArchiveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.vehicleArchiveAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref
        .read(vehicleRepositoryProvider)
        .archive(userId: userId, vehicleId: widget.vehicleId!);
    ref.read(analyticsProvider).track(AnalyticsEvent.vehicleDeleted);
    if (mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final title = widget.isEditing
        ? s.vehicleEditTitle
        : s.vehicleRegisterTitle;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DcoLayout.screenPadding,
              DcoLayout.cardPadding,
              DcoLayout.screenPadding,
              DcoLayout.sectionGap,
            ),
            children: [
              _PhotoPicker(path: _photoPath, onTap: _pickPhoto),
              if (_formError != null) ...[
                SizedBox(height: tokens.space.s4),
                _FormErrorBanner(message: _formError!),
              ],
              SizedBox(height: DcoLayout.sectionGap),
              Text(
                s.vehicleRequiredInfo,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: tokens.space.s4),
              DcoTextField(
                key: const Key('vehicle-name'),
                label: s.vehicleNameLabel,
                controller: _name,
                errorText: _errors['name'],
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _errors['name'] = null),
              ),
              SizedBox(height: tokens.space.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: DcoTextField(
                      key: const Key('vehicle-year'),
                      label: s.vehicleYearLabel,
                      controller: _year,
                      errorText: _errors['year'],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() => _errors['year'] = null),
                    ),
                  ),
                  SizedBox(width: tokens.space.s3),
                  Expanded(
                    flex: 3,
                    child: DcoTextField(
                      key: const Key('vehicle-make'),
                      label: s.vehicleMakeLabel,
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
                label: s.vehicleModelLabel,
                controller: _model,
                errorText: _errors['model'],
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _errors['model'] = null),
              ),
              SizedBox(height: tokens.space.s4),
              DcoTextField(
                key: const Key('vehicle-plate'),
                label: s.vehiclePlateLabel,
                controller: _plate,
                errorText: _errors['plate'],
                maxLength: 20,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _errors['plate'] = null),
              ),
              SizedBox(height: tokens.space.s4),
              DcoTextField(
                key: const Key('vehicle-mileage'),
                label: s.vehicleMileageLabel,
                controller: _mileage,
                errorText: _errors['mileage'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 12),
                  child: Text(
                    lengthUnit.label,
                    style: TextStyle(color: tokens.text.caption),
                  ),
                ),
                onChanged: (_) => setState(() => _errors['mileage'] = null),
              ),
              SizedBox(height: tokens.space.s4),
              Text(
                s.vehicleFuelTypeLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              SizedBox(height: tokens.space.s2),
              Wrap(
                spacing: tokens.space.s2,
                runSpacing: tokens.space.s2,
                children: [
                  for (final type in FuelType.values)
                    _FuelChip(
                      label: type.label,
                      selected: _fuelType == type,
                      onTap: () => setState(() {
                        _fuelType = type;
                        _fuelError = false;
                      }),
                    ),
                ],
              ),
              if (_fuelError) ...[
                SizedBox(height: tokens.space.s2),
                Text(
                  s.vehicleFuelTypeRequired,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.status.dangerFg,
                  ),
                ),
              ],
              SizedBox(height: DcoLayout.sectionGap),
              Text(
                s.vehicleOptionalDetails,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: tokens.space.s4),
              DcoTextField(
                label: s.vehicleVinLabel,
                controller: _vin,
                errorText: _errors['vin'],
                maxLength: 17,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _errors['vin'] = null),
              ),
              SizedBox(height: tokens.space.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DcoTextField(
                      label: s.vehicleColorLabel,
                      controller: _color,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(width: tokens.space.s3),
                  Expanded(
                    child: DcoTextField(
                      label: s.vehicleNicknameLabel,
                      controller: _nickname,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.space.s4),
              DcoTextField(
                label: s.vehiclePurchaseDateLabel,
                controller: _purchaseDate,
                readOnly: true,
                onTap: _pickDate,
                suffix: Icon(
                  Icons.calendar_today_outlined,
                  color: tokens.icon.inactive,
                  size: 18,
                ),
              ),
              if (widget.isEditing && _isOwner) ...[
                SizedBox(height: DcoLayout.sectionGap),
                Divider(height: 1, color: tokens.border.divider),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _archive,
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.status.dangerFg,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space.s2,
                      ),
                    ),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: tokens.status.dangerFg,
                    ),
                    label: Text(
                      s.vehicleArchiveButton,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.background.primary,
          border: Border(top: BorderSide(color: tokens.border.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DcoLayout.screenPadding,
                  vertical: DcoLayout.rowGap,
                ),
                child: DcoButton(
                  key: const Key('vehicle-save'),
                  label: s.save,
                  onPressed: _saving ? null : _save,
                  loading: _saving,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.space.s3),
      decoration: BoxDecoration(
        color: tokens.status.dangerBg,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(
          color: tokens.status.dangerFg.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: tokens.status.dangerFg),
          SizedBox(width: tokens.space.s2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.status.dangerFg),
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
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.radius.lg);
    final hasPhoto = path != null && path!.isNotEmpty;

    return Material(
      color: tokens.background.input,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(path!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 28,
                          color: tokens.icon.inactive,
                        ),
                      ),
                    ),
                    Positioned(
                      right: tokens.space.s3,
                      bottom: tokens.space.s3,
                      child: Tooltip(
                        message: s.vehicleAddPhoto,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.background.primary.withValues(
                              alpha: 0.88,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: tokens.border.divider),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: tokens.text.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tokens.background.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: 22,
                        color: tokens.icon.inactive,
                      ),
                    ),
                    SizedBox(height: tokens.space.s2),
                    Text(
                      s.vehicleAddPhoto,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.text.secondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FuelChip extends StatelessWidget {
  const _FuelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.radius.full);
    return Material(
      color: selected
          ? tokens.button.primary.background
          : tokens.background.input,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: tokens.space.s4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? tokens.border.highlight
                  : tokens.border.defaultColor,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? tokens.text.onAccent : tokens.text.primary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

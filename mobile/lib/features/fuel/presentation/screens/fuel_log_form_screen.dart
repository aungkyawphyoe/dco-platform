import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_catalog_type.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/fuel/domain/fuel_failure.dart';
import 'package:dco_mobile/features/fuel/domain/fuel_validators.dart';
import 'package:dco_mobile/features/fuel/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RefuelFormScreen extends ConsumerWidget {
  const RefuelFormScreen({super.key, this.logId});

  final String? logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FuelLogForm(kind: FuelLogKind.refuel, logId: logId);
  }
}

class ChargeFormScreen extends ConsumerWidget {
  const ChargeFormScreen({super.key, this.logId});

  final String? logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FuelLogForm(kind: FuelLogKind.charge, logId: logId);
  }
}

class FuelLogEntryScreen extends ConsumerWidget {
  const FuelLogEntryScreen({super.key, this.logId});

  final String? logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    if (vehicle != null && fuelLogKindFor(vehicle) == FuelLogKind.charge) {
      return ChargeFormScreen(logId: logId);
    }
    return RefuelFormScreen(logId: logId);
  }
}

class FuelLogForm extends ConsumerStatefulWidget {
  const FuelLogForm({super.key, required this.kind, this.logId});

  final FuelLogKind kind;
  final String? logId;

  bool get isEditing => logId != null;

  @override
  ConsumerState<FuelLogForm> createState() => _FuelLogFormState();
}

class _FuelLogFormState extends ConsumerState<FuelLogForm> {
  final _date = TextEditingController();
  final _fuelTypeLabel = TextEditingController();
  final _amount = TextEditingController();
  final _cost = TextEditingController();
  final _errors = <String, String?>{};

  DateTime _loggedOn = DateTime.now();
  String? _fuelTypeId;
  String? _formError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date.text = DateFormat.yMMMd().format(_loggedOn);
    _hydrate();
  }

  Future<void> _hydrate() async {
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle != null) {
      await ref.read(fuelRepositoryProvider).ensureDefaultFuelTypes(vehicle.userId);
    }

    if (widget.logId != null) {
      final log = await ref.read(fuelRepositoryProvider).getLog(widget.logId!);
      if (log != null && mounted) {
        _loggedOn = log.loggedOn;
        _date.text = DateFormat.yMMMd().format(log.loggedOn);
        _fuelTypeId = log.fuelTypeId;
        _fuelTypeLabel.text = log.fuelTypeName;
        _amount.text = _formatNumber(log.amount);
        _cost.text = MoneyFormat.input(log.cost, ref.read(currencyProvider).code);
      }
    } else if (vehicle != null) {
      final types = await ref
          .read(fuelRepositoryProvider)
          .watchFuelTypes(vehicle.userId, kind: widget.kind.catalogKind)
          .first;
      if (types.isNotEmpty && mounted) {
        _fuelTypeId = types.first.id;
        _fuelTypeLabel.text = types.first.name;
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _date.dispose();
    _fuelTypeLabel.dispose();
    _amount.dispose();
    _cost.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  FuelLogDraft? _draftOrNull() {
    setState(() {
      _errors
        ..['date'] = FuelLogValidators.date(_loggedOn, now: DateTime.now())
        ..['type'] = FuelLogValidators.fuelTypeId(_fuelTypeId)
        ..['amount'] = FuelLogValidators.amount(_amount.text)
        ..['cost'] = FuelLogValidators.cost(_cost.text);
      _formError = null;
    });
    if (_errors.values.any((error) => error != null)) return null;
    return FuelLogDraft(
      loggedOn: _loggedOn,
      fuelTypeId: _fuelTypeId!,
      amount: FuelLogValidators.parseDecimal(_amount.text)!,
      cost: FuelLogValidators.parseDecimal(_cost.text)!,
    );
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
        await repo.updateLog(
          userId: vehicle.userId,
          logId: widget.logId!,
          kind: widget.kind,
          draft: draft,
        );
        ref.read(analyticsProvider).track(AnalyticsEvent.fuelLogUpdated);
      } else {
        await repo.addLog(
          userId: vehicle.userId,
          vehicleId: vehicle.id,
          kind: widget.kind,
          draft: draft,
        );
        ref.read(analyticsProvider).track(AnalyticsEvent.fuelLogAdded);
      }
      if (mounted) context.pop();
    } on FuelFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _loggedOn.isAfter(now) ? now : _loggedOn,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      _loggedOn = picked;
      _date.text = DateFormat.yMMMd().format(picked);
      _errors['date'] = null;
    });
  }

  Future<void> _pickFuelType(List<FuelCatalogType> types) async {
    if (types.isEmpty) {
      await context.push(AppRoutes.fuelTypeNew, extra: widget.kind.catalogKind);
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.tokens.background.card,
      builder: (context) {
        final tokens = context.tokens;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(tokens.space.s4, tokens.space.s4, tokens.space.s4, tokens.space.s2),
                child: Text('Fuel Type', style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final type in types)
                ListTile(
                  title: Text(type.name),
                  subtitle: Text(type.unit, style: TextStyle(color: tokens.text.caption)),
                  trailing: type.id == _fuelTypeId ? Icon(Icons.check, color: tokens.text.accent) : null,
                  onTap: () => Navigator.pop(context, type.id),
                ),
              ListTile(
                leading: Icon(Icons.add, color: tokens.text.accent),
                title: const Text('Add fuel type'),
                onTap: () => Navigator.pop(context, '__add__'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected == '__add__') {
      await context.push(AppRoutes.fuelTypeNew, extra: widget.kind.catalogKind);
      return;
    }
    FuelCatalogType? type;
    for (final item in types) {
      if (item.id == selected) {
        type = item;
        break;
      }
    }
    setState(() {
      _fuelTypeId = selected;
      _fuelTypeLabel.text = type?.name ?? '';
      _errors['type'] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final types = ref.watch(matchingFuelTypesProvider);
    final currency = ref.watch(currencyProvider).code;
    FuelCatalogType? selected;
    for (final type in types) {
      if (type.id == _fuelTypeId) {
        selected = type;
        break;
      }
    }
    final unit = selected?.unit ?? widget.kind.catalogKind.defaultUnit;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? widget.kind.editLabel : widget.kind.addLabel)),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? widget.kind.editLabel : widget.kind.addLabel),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.fuelTypes),
            child: Text('Fuel Types', style: TextStyle(color: tokens.text.link)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                DcoTextField(
                  key: const Key('fuel-log-date'),
                  label: 'Date *',
                  controller: _date,
                  readOnly: true,
                  onTap: _pickDate,
                  errorText: _errors['date'],
                  suffix: Icon(Icons.calendar_today_outlined, color: tokens.icon.inactive),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('fuel-log-type'),
                  label: 'Fuel Type *',
                  controller: _fuelTypeLabel,
                  hint: types.isEmpty ? 'Add a fuel type' : 'Select',
                  readOnly: true,
                  onTap: () => _pickFuelType(types),
                  errorText: _errors['type'],
                  suffix: Icon(Icons.expand_more, color: tokens.icon.inactive),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('fuel-log-amount'),
                  label: 'Amount *',
                  controller: _amount,
                  hint: widget.kind == FuelLogKind.charge ? '32' : '40',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  errorText: _errors['amount'],
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 12),
                    child: Text(unit, style: TextStyle(color: tokens.text.caption)),
                  ),
                  onChanged: (_) => setState(() => _errors['amount'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('fuel-log-cost'),
                  label: 'Cost *',
                  controller: _cost,
                  hint: MoneyFormat.isMmk(currency) ? '0' : '0.00',
                  keyboardType: TextInputType.numberWithOptions(decimal: !MoneyFormat.isMmk(currency)),
                  textInputAction: TextInputAction.done,
                  errorText: _errors['cost'],
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 12),
                    child: Text(currency, style: TextStyle(color: tokens.text.caption)),
                  ),
                  onChanged: (_) => setState(() => _errors['cost'] = null),
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
                    key: const Key('fuel-log-save'),
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

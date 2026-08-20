import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/domain/maintenance_failure.dart';
import 'package:dco_mobile/features/maintenance/domain/plan_item_validators.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
import 'package:dco_mobile/features/maintenance/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RegisterServiceScreen extends ConsumerStatefulWidget {
  const RegisterServiceScreen({super.key, this.preselectedPlanItemId});

  final String? preselectedPlanItemId;

  @override
  ConsumerState<RegisterServiceScreen> createState() => _RegisterServiceScreenState();
}

class _RegisterServiceScreenState extends ConsumerState<RegisterServiceScreen> {
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _mileage = TextEditingController();
  final _notes = TextEditingController();
  final _total = TextEditingController();
  final _errors = <String, String?>{};
  final _lines = <_ServiceLineInput>[];

  DateTime _servicedOn = DateTime.now();
  String? _formError;
  bool _saving = false;
  bool _totalTouched = false;
  bool _mileagePrefill = false;
  bool _itemPrefill = false;

  @override
  void initState() {
    super.initState();
    _date.text = DateFormat.yMMMd().format(_servicedOn);
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _mileage.dispose();
    _notes.dispose();
    _total.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _prefill(Vehicle vehicle, List<PlanItem> plan) {
    if (!_mileagePrefill) {
      _mileagePrefill = true;
      _mileage.text = MileageFormat.input(vehicle.mileage, ref.read(lengthUnitProvider));
    }
    final preselected = widget.preselectedPlanItemId;
    if (!_itemPrefill && preselected != null) {
      final match = plan.where((item) => item.id == preselected);
      if (match.isNotEmpty) {
        _itemPrefill = true;
        _addLine(match.first);
      }
    }
  }

  void _addLine(PlanItem item) {
    if (_lines.any((line) => line.planItemId == item.id)) return;
    setState(() {
      _lines.add(_ServiceLineInput(name: item.name, planItemId: item.id));
      _syncTitleAndTotal();
    });
  }

  void _addCustomLine(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _lines.add(_ServiceLineInput(name: trimmed));
      _syncTitleAndTotal();
    });
  }

  void _removeLine(_ServiceLineInput line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
      _syncTitleAndTotal();
    });
  }

  void _syncTitleAndTotal() {
    if (_title.text.trim().isEmpty) {
      _title.text = _lines.map((line) => line.name).join(', ');
    }
    if (!_totalTouched) {
      final sum = _lines.fold<double>(0, (total, line) => total + (line.cost ?? 0));
      _total.text = sum == 0 ? '' : (sum.truncateToDouble() == sum ? sum.toStringAsFixed(0) : sum.toString());
    }
  }

  ServiceRecordDraft? _draftOrNull() {
    final parsed = PlanItemValidators.parseMileage(_mileage.text);
    final odometer = parsed == null ? null : ref.read(lengthUnitProvider).toStorage(parsed);
    final total = ServiceRecordValidators.parseCost(_total.text) ??
        _lines.fold<double>(0, (sum, line) => sum + (line.cost ?? 0));
    final items = _lines
        .map(
          (line) => ServiceLineDraft(
            name: line.name,
            planItemId: line.planItemId,
            lineCost: line.cost,
          ),
        )
        .toList();

    setState(() {
      _errors
        ..['date'] = ServiceRecordValidators.date(_servicedOn)
        ..['mileage'] = ServiceRecordValidators.odometer(_mileage.text)
        ..['items'] = ServiceRecordValidators.items(items)
        ..['total'] = ServiceRecordValidators.totalCost(total.toString());
      _formError = _errors['items'];
    });
    if (_errors.values.any((error) => error != null) || odometer == null) return null;

    return ServiceRecordDraft(
      title: _title.text,
      servicedOn: _servicedOn,
      odometer: odometer,
      totalCost: total,
      notes: _notes.text,
      items: items,
    );
  }

  Future<void> _save() async {
    final draft = _draftOrNull();
    if (draft == null) return;
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(maintenanceRepositoryProvider).registerService(
        userId: vehicle.userId,
        vehicle: vehicle,
        draft: draft,
      );
      ref.read(analyticsProvider).track(AnalyticsEvent.maintenanceRecordAdded);
      if (draft.items.any((item) => item.planItemId != null)) {
        ref.read(analyticsProvider).track(AnalyticsEvent.maintenanceReminderCompleted);
      }
      if (mounted) context.pop();
    } on MaintenanceFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _servicedOn,
      firstDate: DateTime(1900),
      lastDate: DateTime(ServiceRecordValidators.maxServiceYear(), 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _servicedOn = picked;
      _date.text = DateFormat.yMMMd().format(picked);
      _errors['date'] = null;
    });
  }

  Future<void> _openAddService(Vehicle vehicle, List<PlanItem> plan) async {
    final now = DateTime.now();
    final lengthUnit = ref.read(lengthUnitProvider);
    final available = plan.where((item) {
      if (!item.enabled) return false;
      if (_lines.any((line) => line.planItemId == item.id)) return false;
      final urgency = DueCalculator.urgency(
        item: item,
        vehicleMileage: vehicle.mileage,
        now: now,
      );
      return urgency != PlanUrgency.hidden;
    }).toList();
    final custom = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.background.card,
      builder: (context) {
        final tokens = context.tokens;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space.s4,
            tokens.space.s4,
            tokens.space.s4,
            MediaQuery.viewInsetsOf(context).bottom + tokens.space.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add service', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.space.s3),
              if (available.isEmpty)
                Text(
                  'No due or scheduled items left. Add a custom service below.',
                  style: TextStyle(color: tokens.text.caption),
                )
              else
                ...available.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      DueCalculator.intervalLabel(
                        intervalDays: item.intervalDays,
                        intervalDistance: item.intervalDistance == null
                            ? null
                            : lengthUnit.toDisplay(item.intervalDistance!),
                        unit: lengthUnit.label,
                      ),
                    ),
                    onTap: () {
                      _addLine(item);
                      Navigator.pop(context);
                    },
                  ),
                ),
              SizedBox(height: tokens.space.s3),
              DcoTextField(
                label: 'Custom service',
                controller: custom,
                hint: 'e.g. Alignment',
              ),
              SizedBox(height: tokens.space.s3),
              DcoButton(
                label: 'Add custom',
                onPressed: () {
                  _addCustomLine(custom.text);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
    custom.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final plan = ref.watch(maintenancePlanProvider).valueOrNull ?? const <PlanItem>[];
    if (vehicle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefill(vehicle, plan);
      });
    }

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Register Service')),
        body: const DcoEmptyState(
          title: 'No active vehicle',
          body: 'Register a vehicle before logging a service.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Register Service')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                DcoTextField(
                  label: 'Job Title',
                  controller: _title,
                  hint: 'ABC123',
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'Date *',
                  controller: _date,
                  hint: 'dd/mm/yyyy',
                  errorText: _errors['date'],
                  readOnly: true,
                  onTap: _pickDate,
                  suffix: Icon(Icons.calendar_today_outlined, color: tokens.icon.inactive, size: 18),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('register-mileage'),
                  label: 'Mileage *',
                  controller: _mileage,
                  hint: '*** ${lengthUnit.label}',
                  errorText: _errors['mileage'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 12),
                    child: Text(lengthUnit.label, style: TextStyle(color: tokens.text.caption)),
                  ),
                  onChanged: (_) => setState(() => _errors['mileage'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'Notes',
                  controller: _notes,
                  hint: 'write a message',
                  maxLines: 4,
                  minLines: 3,
                ),
                SizedBox(height: tokens.space.s5),
                Text('Service', style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s3),
                ..._lines.map(
                  (line) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.space.s3),
                    child: Material(
                      color: tokens.background.card,
                      borderRadius: BorderRadius.circular(tokens.radius.md),
                      child: Padding(
                        padding: EdgeInsets.all(tokens.space.s3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(line.name, style: Theme.of(context).textTheme.titleMedium),
                            ),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: line.costController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(hintText: 'cost'),
                                onChanged: (_) => setState(_syncTitleAndTotal),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => _removeLine(line),
                              icon: Icon(Icons.close, color: tokens.icon.inactive),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openAddService(vehicle, plan),
                  icon: Icon(Icons.add, color: tokens.icon.active),
                  label: Text('add service', style: TextStyle(color: tokens.text.link)),
                ),
                if (_errors['items'] != null) ...[
                  SizedBox(height: tokens.space.s2),
                  Text(_errors['items']!, style: TextStyle(color: tokens.status.dangerFg)),
                ],
                SizedBox(height: tokens.space.s5),
                DcoTextField(
                  label: 'Total',
                  controller: _total,
                  hint: '***',
                  errorText: _errors['total'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    _totalTouched = true;
                    setState(() => _errors['total'] = null);
                  },
                ),
                if (_formError != null) ...[
                  SizedBox(height: tokens.space.s4),
                  Text(_formError!, style: TextStyle(color: tokens.status.dangerFg)),
                ],
              ],
            ),
          ),
          DcoStickyActions(
            secondaryLabel: 'Cancel',
            onSecondary: () => context.pop(),
            primaryLabel: 'Save',
            onPrimary: _save,
            primaryLoading: _saving,
            primaryKey: const Key('register-service-save'),
          ),
        ],
      ),
    );
  }
}

class _ServiceLineInput {
  _ServiceLineInput({required this.name, this.planItemId}) : costController = TextEditingController();

  final String name;
  final String? planItemId;
  final TextEditingController costController;

  double? get cost => ServiceRecordValidators.parseCost(costController.text);

  void dispose() => costController.dispose();
}

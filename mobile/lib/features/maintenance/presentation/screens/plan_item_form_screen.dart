import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/maintenance_failure.dart';
import 'package:dco_mobile/features/maintenance/domain/plan_item_validators.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PlanItemFormScreen extends ConsumerStatefulWidget {
  const PlanItemFormScreen({super.key, this.planItemId});

  final String? planItemId;

  bool get isEditing => planItemId != null;

  @override
  ConsumerState<PlanItemFormScreen> createState() => _PlanItemFormScreenState();
}

class _PlanItemFormScreenState extends ConsumerState<PlanItemFormScreen> {
  final _name = TextEditingController();
  final _date = TextEditingController();
  final _mileage = TextEditingController();
  final _notes = TextEditingController();
  final _intervalCount = TextEditingController();
  final _intervalDistance = TextEditingController();
  final _errors = <String, String?>{};

  bool _recurring = true;
  TimeIntervalUnit _unit = TimeIntervalUnit.years;
  DateTime? _dateValue;
  String? _formError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.planItemId == null) {
      setState(() => _loading = false);
      return;
    }
    final item = await ref.read(maintenanceRepositoryProvider).getPlanItem(widget.planItemId!);
    if (!mounted) return;
    if (item != null) {
      _name.text = item.name;
      _recurring = item.recurring;
      _notes.text = item.notes ?? '';
      if (item.nextDueOn != null) {
        _dateValue = item.nextDueOn;
        _date.text = DateFormat.yMMMd().format(item.nextDueOn!);
      }
      if (item.nextDueMileage != null) {
        _mileage.text = _num(item.nextDueMileage!);
      }
      if (item.intervalDays != null) {
        final decoded = TimeIntervalUnit.fromDays(item.intervalDays!);
        _intervalCount.text = '${decoded.value}';
        _unit = decoded.unit;
      }
      if (item.intervalDistance != null) {
        _intervalDistance.text = _num(item.intervalDistance!);
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _date.dispose();
    _mileage.dispose();
    _notes.dispose();
    _intervalCount.dispose();
    _intervalDistance.dispose();
    super.dispose();
  }

  PlanItemDraft? _draftOrNull() {
    final intervalCount = PlanItemValidators.parseIntervalCount(_intervalCount.text);
    final intervalDays = !_recurring || intervalCount == null ? null : _unit.toDays(intervalCount);
    final intervalDistance = _recurring ? PlanItemValidators.parseMileage(_intervalDistance.text) : null;
    final mileage = PlanItemValidators.parseMileage(_mileage.text);

    setState(() {
      _errors
        ..['name'] = PlanItemValidators.name(_name.text)
        ..['interval'] = _recurring ? PlanItemValidators.intervalCount(_intervalCount.text) : null
        ..['distance'] = _recurring
            ? PlanItemValidators.mileage(_intervalDistance.text, required: false)
            : null
        ..['mileage'] = PlanItemValidators.mileage(_mileage.text, required: false)
        ..['schedule'] = PlanItemValidators.schedule(
          recurring: _recurring,
          intervalDays: intervalDays,
          intervalDistance: intervalDistance,
          date: _dateValue,
          mileage: mileage,
        );
      _formError = _errors['schedule'];
    });
    if (_errors.values.any((error) => error != null)) return null;

    return PlanItemDraft(
      name: _name.text,
      recurring: _recurring,
      intervalDays: intervalDays,
      intervalDistance: intervalDistance,
      date: _dateValue,
      mileage: mileage,
      notes: _notes.text,
    );
  }

  Future<void> _save() async {
    final draft = _draftOrNull();
    if (draft == null) return;
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (widget.isEditing) {
        await repo.updatePlanItem(
          userId: vehicle.userId,
          vehicle: vehicle,
          planItemId: widget.planItemId!,
          draft: draft,
        );
      } else {
        await repo.addPlanItem(userId: vehicle.userId, vehicle: vehicle, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.maintenancePlanItemAdded);
      }
      if (mounted) context.pop();
    } on MaintenanceFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateValue ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _dateValue = picked;
      _date.text = DateFormat.yMMMd().format(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final unit = ref.watch(activeVehicleProvider).valueOrNull?.mileageUnit.label ?? 'mi';
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit Service Item' : 'Create Service Item')),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Service Item' : 'Create Service Item')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                DcoTextField(
                  key: const Key('plan-item-name'),
                  label: 'Name *',
                  controller: _name,
                  errorText: _errors['name'],
                  maxLength: PlanItemValidators.maxNameLength,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['name'] = null),
                ),
                SizedBox(height: tokens.space.s5),
                Text('Schedule *', style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s2),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: 'active',
                        selected: !_recurring,
                        onTap: () => setState(() => _recurring = false),
                      ),
                    ),
                    SizedBox(width: tokens.space.s3),
                    Expanded(
                      child: _ModeChip(
                        label: 'recurring',
                        selected: _recurring,
                        onTap: () => setState(() => _recurring = true),
                      ),
                    ),
                  ],
                ),
                if (_recurring) ...[
                  SizedBox(height: tokens.space.s5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DcoTextField(
                          label: 'Repeat every',
                          controller: _intervalCount,
                          hint: '1',
                          errorText: _errors['interval'],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {
                            _errors['interval'] = null;
                            _errors['schedule'] = null;
                            _formError = null;
                          }),
                        ),
                      ),
                      SizedBox(width: tokens.space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unit', style: Theme.of(context).textTheme.labelLarge),
                            SizedBox(height: tokens.space.s2),
                            DropdownButtonFormField<TimeIntervalUnit>(
                              initialValue: _unit,
                              items: TimeIntervalUnit.values
                                  .map(
                                    (unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _unit = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space.s4),
                  DcoTextField(
                    label: 'Every (mileage)',
                    controller: _intervalDistance,
                    hint: '15000',
                    errorText: _errors['distance'],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 12),
                      child: Text(unit, style: TextStyle(color: tokens.text.caption)),
                    ),
                    onChanged: (_) => setState(() {
                      _errors['distance'] = null;
                      _errors['schedule'] = null;
                      _formError = null;
                    }),
                  ),
                  SizedBox(height: tokens.space.s5),
                  Text('Override Tracking Start', style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: tokens.space.s2),
                  Text(
                    'The highest value out of this or your most recent service will prevail.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                ],
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: _recurring ? 'Date' : 'Date *',
                  controller: _date,
                  hint: 'dd/mm/yyyy',
                  readOnly: true,
                  onTap: _pickDate,
                  suffix: Icon(Icons.calendar_today_outlined, color: tokens.icon.inactive, size: 18),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: _recurring ? 'Mileage' : 'Mileage *',
                  controller: _mileage,
                  hint: '*** $unit',
                  errorText: _errors['mileage'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 12),
                    child: Text(unit, style: TextStyle(color: tokens.text.caption)),
                  ),
                  onChanged: (_) => setState(() {
                    _errors['mileage'] = null;
                    _errors['schedule'] = null;
                    _formError = null;
                  }),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'Notes',
                  controller: _notes,
                  hint: 'write a message',
                  maxLines: 4,
                  minLines: 3,
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
            primaryKey: const Key('plan-item-save'),
          ),
        ],
      ),
    );
  }

  String _num(double value) {
    return value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toString();
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.text.accent : tokens.background.input,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? tokens.text.onAccent : tokens.text.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

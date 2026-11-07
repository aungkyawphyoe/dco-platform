import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/maintenance_failure.dart';
import 'package:dco_mobile/features/maintenance/domain/plan_item_validators.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<void> showPlanItemForm(
  BuildContext context, {
  String? planItemId,
  String? initialName,
  String? catalogKey,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: context.tokens.background.card,
  builder: (_) => _PlanItemSheet(
    child: PlanItemFormScreen(
      planItemId: planItemId,
      initialName: initialName,
      catalogKey: catalogKey,
    ),
  ),
);

class PlanItemFormPage extends Page<void> {
  const PlanItemFormPage({super.key, this.planItemId});
  final String? planItemId;

  @override
  Route<void> createRoute(BuildContext context) => ModalBottomSheetRoute<void>(
    settings: this,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.tokens.background.card,
    builder: (_) =>
        _PlanItemSheet(child: PlanItemFormScreen(planItemId: planItemId)),
  );
}

class _PlanItemSheet extends StatelessWidget {
  const _PlanItemSheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SizedBox(
          height:
              (constraints.maxHeight - keyboard).clamp(
                0,
                constraints.maxHeight,
              ) *
              .95,
          child: child,
        ),
      );
    },
  );
}

class PlanItemFormScreen extends ConsumerStatefulWidget {
  const PlanItemFormScreen({
    super.key,
    this.planItemId,
    this.initialName,
    this.catalogKey,
  });

  final String? planItemId;
  final String? initialName;
  final String? catalogKey;

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

  bool _enabled = true;
  bool _recurring = true;
  TimeIntervalUnit _unit = TimeIntervalUnit.months;
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
    _name.text = widget.initialName ?? '';
    if (widget.planItemId == null) {
      setState(() => _loading = false);
      return;
    }
    final item = await ref
        .read(maintenanceRepositoryProvider)
        .getPlanItem(widget.planItemId!);
    if (!mounted) return;
    final length = ref.read(lengthUnitProvider);
    if (item != null) {
      _name.text = item.name;
      _enabled = item.enabled;
      _recurring = item.recurring;
      _notes.text = item.notes ?? '';
      if (item.nextDueOn != null) {
        _dateValue = item.nextDueOn;
        _date.text = DateFormat.yMMMd().format(item.nextDueOn!);
      }
      if (item.nextDueMileage != null) {
        _mileage.text = MileageFormat.input(item.nextDueMileage!, length);
      }
      if (item.timeCount != null && item.timeUnit != null) {
        _intervalCount.text = '${item.timeCount}';
        _unit = TimeIntervalUnit.values.byName(item.timeUnit!);
      } else if (item.intervalDays != null) {
        final decoded = TimeIntervalUnit.fromDays(item.intervalDays!);
        _intervalCount.text = '${decoded.value}';
        _unit = decoded.unit;
      }
      if (item.intervalDistance != null) {
        _intervalDistance.text = MileageFormat.input(
          item.intervalDistance!,
          length,
        );
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
    final s = AppLocalizations.of(context)!;
    final length = ref.read(lengthUnitProvider);
    final hasDate = _dateValue != null;
    final hasOdometer = _mileage.text.trim().isNotEmpty;
    final intervalCount = PlanItemValidators.parseIntervalCount(
      hasDate ? _intervalCount.text : '',
    );
    final intervalDays = !_recurring || intervalCount == null
        ? null
        : _unit.toDays(intervalCount);
    final parsedDistance = _recurring && hasOdometer
        ? PlanItemValidators.parseMileage(_intervalDistance.text)
        : null;
    final intervalDistance = parsedDistance == null
        ? null
        : length.toStorage(parsedDistance);
    final parsedMileage = PlanItemValidators.parseMileage(_mileage.text);
    final mileage = parsedMileage == null
        ? null
        : length.toStorage(parsedMileage);

    setState(() {
      _errors
        ..['name'] = PlanItemValidators.name(_name.text)
        ..['date'] = !hasDate && !hasOdometer ? s.planDueTargetRequired : null
        ..['interval'] = _recurring && hasDate
            ? (_intervalCount.text.trim().isEmpty
                  ? s.planRepeatTimeRequired
                  : PlanItemValidators.intervalCount(_intervalCount.text))
            : null
        ..['distance'] = _recurring && hasOdometer
            ? (_intervalDistance.text.trim().isEmpty
                  ? s.planRepeatDistanceRequired
                  : (PlanItemValidators.parseMileage(_intervalDistance.text) ??
                            0) <=
                        0
                  ? s.planRepeatDistanceRequired
                  : PlanItemValidators.mileage(
                      _intervalDistance.text,
                      required: true,
                    ))
            : null
        ..['mileage'] = !hasDate && !hasOdometer
            ? s.planDueTargetRequired
            : PlanItemValidators.mileage(_mileage.text, required: false)
        ..['schedule'] = PlanItemValidators.schedule(
          recurring: _recurring,
          intervalDays: intervalDays,
          intervalDistance: intervalDistance,
          date: _dateValue,
          mileage: mileage,
        );
      _formError =
          _errors['date'] != null ||
              _errors['interval'] != null ||
              _errors['distance'] != null
          ? null
          : _errors['schedule'];
    });
    if (_errors.values.any((error) => error != null)) return null;

    return PlanItemDraft(
      name: _name.text,
      recurring: _recurring,
      timeCount: _recurring ? intervalCount : null,
      timeUnit: _recurring && intervalCount != null ? _unit.name : null,
      intervalDays: intervalDays,
      intervalDistance: intervalDistance,
      date: _dateValue,
      mileage: mileage,
      notes: _notes.text,
      enabled: _enabled,
      catalogKey: widget.catalogKey,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
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
        await repo.addPlanItem(
          userId: vehicle.userId,
          vehicle: vehicle,
          draft: draft,
        );
        ref
            .read(analyticsProvider)
            .track(AnalyticsEvent.maintenancePlanItemAdded);
      }
      if (mounted) Navigator.of(context).pop();
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
    if (picked == null || !mounted) return;
    setState(() {
      _dateValue = picked;
      _errors['date'] = null;
      _errors['mileage'] = null;
      _formError = null;
      _date.text = DateFormat.yMMMd().format(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final unit = ref.watch(lengthUnitProvider).label;
    return PopScope(
      canPop: !_saving,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: tokens.space.s4,
              right: tokens.space.s2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isEditing
                        ? s.planItemFormEditTitle
                        : s.planItemFormCreateTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: s.close,
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: tokens.text.accent),
                  )
                : ListView(
                    padding: EdgeInsets.all(tokens.space.s4),
                    children: [
                      DcoTextField(
                        key: const Key('plan-item-name'),
                        label: s.planItemFormName,
                        controller: _name,
                        errorText: _errors['name'],
                        maxLength: PlanItemValidators.maxNameLength,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) =>
                            setState(() => _errors['name'] = null),
                      ),
                      SizedBox(height: tokens.space.s4),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DcoTextField(
                              key: const Key('plan-item-date'),
                              label: s.planItemFormNextDate,
                              controller: _date,
                              hint: 'dd/mm/yyyy',
                              errorText: _errors['date'],
                              readOnly: true,
                              onTap: _pickDate,
                              suffix: _dateValue == null
                                  ? Icon(
                                      Icons.calendar_today_outlined,
                                      color: tokens.icon.inactive,
                                      size: 18,
                                    )
                                  : IconButton(
                                      key: const Key('plan-item-clear-date'),
                                      tooltip:
                                          '${s.remove} ${s.planItemFormNextDate}',
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(() {
                                        _dateValue = null;
                                        _date.clear();
                                        _errors['date'] = null;
                                        _errors['interval'] = null;
                                        _errors['schedule'] = null;
                                        _formError = null;
                                      }),
                                    ),
                            ),
                          ),
                          SizedBox(width: tokens.space.s3),
                          Expanded(
                            child: DcoTextField(
                              key: const Key('plan-item-mileage'),
                              label: '${s.planItemFormNextOdometer} ($unit)',
                              controller: _mileage,
                              hint: '*** ${lengthUnit.label}',
                              errorText: _errors['mileage'],
                              helperText: s.registerServiceCurrentMileage(
                                MileageFormat.labeled(
                                  vehicle?.mileage ?? 0,
                                  lengthUnit,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {
                                _errors['mileage'] = null;
                                _errors['date'] = null;
                                _errors['schedule'] = null;
                                _formError = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space.s4),
                      SwitchListTile(
                        key: const Key('plan-item-recurring'),
                        value: _recurring,
                        onChanged: (value) => setState(() {
                          _recurring = value;
                          _errors['interval'] = null;
                          _errors['distance'] = null;
                          _errors['schedule'] = null;
                          _formError = null;
                        }),
                        activeThumbColor: tokens.text.accent,
                        title: Text(s.planItemFormRecurring),
                        subtitle: Text(s.planItemFormRecurringHelper),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_recurring &&
                          (_dateValue != null ||
                              _mileage.text.trim().isNotEmpty)) ...[
                        SizedBox(height: tokens.space.s3),
                        if (_dateValue != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DcoTextField(
                                  key: const Key('plan-item-repeat-time'),
                                  label: s.planItemFormRepeatEvery,
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
                                    Text(
                                      s.planItemFormUnit,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    SizedBox(height: tokens.space.s2),
                                    DropdownButtonFormField<TimeIntervalUnit>(
                                      initialValue: _unit,
                                      items: TimeIntervalUnit.values
                                          .where(
                                            (unit) =>
                                                unit != TimeIntervalUnit.days ||
                                                _unit == TimeIntervalUnit.days,
                                          )
                                          .map(
                                            (unit) => DropdownMenuItem(
                                              value: unit,
                                              enabled:
                                                  unit != TimeIntervalUnit.days,
                                              child: Text(unit.label),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _unit = value);
                                      },
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: tokens.background.input,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            tokens.radius.md,
                                          ),
                                          borderSide: BorderSide(
                                            color: tokens.border.subtle,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            tokens.radius.md,
                                          ),
                                          borderSide: BorderSide(
                                            color: tokens.border.subtle,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            tokens.radius.md,
                                          ),
                                          borderSide: BorderSide(
                                            color: tokens
                                                .button
                                                .primary
                                                .background,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: tokens.space.s3,
                                          vertical: tokens.space.s2,
                                        ),
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: tokens.text.primary,
                                          ),
                                      dropdownColor: tokens.background.card,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: tokens.space.s4),
                        if (_mileage.text.trim().isNotEmpty)
                          DcoTextField(
                            key: const Key('plan-item-repeat-distance'),
                            label: s.planItemFormEveryMileage,
                            controller: _intervalDistance,
                            hint: '15000',
                            errorText: _errors['distance'],
                            keyboardType: TextInputType.number,
                            suffix: Padding(
                              padding: const EdgeInsets.only(
                                right: 12,
                                top: 12,
                              ),
                              child: Text(
                                unit,
                                style: TextStyle(color: tokens.text.caption),
                              ),
                            ),
                            onChanged: (_) => setState(() {
                              _errors['distance'] = null;
                              _errors['schedule'] = null;
                              _formError = null;
                            }),
                          ),
                      ],
                      SizedBox(height: tokens.space.s4),
                      DcoTextField(
                        key: const Key('plan-item-notes'),
                        label: s.planItemFormNotes,
                        controller: _notes,
                        maxLines: 4,
                        minLines: 3,
                      ),
                      SizedBox(height: tokens.space.s3),
                      SwitchListTile(
                        key: const Key('plan-item-active'),
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                        activeThumbColor: tokens.text.accent,
                        title: Text(s.planItemFormActive),
                        subtitle: Text(s.planItemFormActiveHelper),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_formError != null) ...[
                        SizedBox(height: tokens.space.s4),
                        Text(
                          _formError!,
                          style: TextStyle(color: tokens.status.dangerFg),
                        ),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: DcoStickyActions(
              primaryLabel: s.save,
              onPrimary: _loading || _saving ? null : _save,
              primaryLoading: _saving,
              primaryKey: const Key('plan-item-save'),
            ),
          ),
        ],
      ),
    );
  }
}

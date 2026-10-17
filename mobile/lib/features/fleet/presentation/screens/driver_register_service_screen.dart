import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_plan_item.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Driver maintenance logging — Maintenance tab → **Register service**
/// (Confirmed Access Decision 18): a shared form with a **Report | Do myself**
/// segmented control (default: Do myself).
///
/// * **Do myself** → `POST /drivers/vehicles/{id}/service-records` — shows as
///   Completed immediately. Plan-linked logs advance the plan item; free-text
///   logs are orphans. Cost is required.
/// * **Report** → work order (`scheduled_service`, optional `plan_item_id`) —
///   shows as Reported in Maintenance history and flips to Completed when the
///   fleet completes it. The cost itself is captured at completion
///   (Decision 19), so this branch collects description instead.
class DriverRegisterServiceScreen extends ConsumerStatefulWidget {
  const DriverRegisterServiceScreen({super.key, this.initialPlanItemId});

  final String? initialPlanItemId;

  @override
  ConsumerState<DriverRegisterServiceScreen> createState() =>
      _DriverRegisterServiceScreenState();
}

class _DriverRegisterServiceScreenState
    extends ConsumerState<DriverRegisterServiceScreen> {
  static const _uuid = Uuid();

  final _odometer = TextEditingController();
  final _cost = TextEditingController();
  final _item = TextEditingController();
  final _notes = TextEditingController();

  final _errors = <String, String?>{};
  bool _doMyself = true;
  String? _planItemId;
  DateTime _servicedOn = DateTime.now();
  bool _saving = false;
  bool _planSeeded = false;

  @override
  void dispose() {
    _odometer.dispose();
    _cost.dispose();
    _item.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(String orgId, String vehicleId) async {
    final s = AppLocalizations.of(context)!;
    final odometer = int.tryParse(_odometer.text.trim());
    final freeText = _item.text.trim();
    final notes = _notes.text.trim();
    setState(() {
      _errors
        ..['odometer'] = (odometer == null || odometer < 0)
            ? s.required
            : null
        ..['item'] = (_planItemId == null && freeText.isEmpty)
            ? s.required
            : null;
      if (_doMyself) {
        final cost = double.tryParse(_cost.text.trim());
        _errors['cost'] = (cost == null || cost < 0) ? s.required : null;
      } else {
        _errors['description'] = notes.length < 10 ? s.required : null;
      }
    });
    if (_errors.values.any((error) => error != null)) return;

    setState(() => _saving = true);
    try {
      if (_doMyself) {
        await ref.read(fleetRepositoryProvider).logDriverServiceRecord(
              vehicleId,
              id: _uuid.v4(),
              servicedOn: DateFormat('yyyy-MM-dd').format(_servicedOn),
              odometerKm: odometer!,
              totalCost: double.parse(_cost.text.trim()),
              planItemId: _planItemId,
              name: _planItemId == null ? freeText : null,
              notes: notes.isEmpty ? null : notes,
            );
      } else {
        final description = freeText.isEmpty
            ? notes
            : '$freeText — $notes';
        await ref.read(fleetRepositoryProvider).createWorkOrder(
              orgId,
              vehicleId: vehicleId,
              odometerKm: odometer!,
              issueType: 'scheduled_service',
              description: description,
              urgency: 'medium',
              planItemId: _planItemId,
            );
      }
      if (!mounted) return;
      ref.invalidate(driverMaintenanceHistoryProvider(vehicleId));
      if (_planItemId != null) {
        ref.invalidate(driverPlanItemsProvider(vehicleId));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _doMyself ? s.driverRegisterSubmitted : s.driverRegisterReportSubmitted,
          ),
        ),
      );
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
    final currency = ref.watch(currencyProvider).code;

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverRegisterServiceTitle)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    if (myVehicle?.hasAssignedVehicle != true) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverRegisterServiceTitle)),
        body: DcoEmptyState(
          title: s.driverNoVehicleTitle,
          body: s.driverNoVehicleBody,
        ),
      );
    }

    final vehicle = myVehicle!.vehicle!;
    final plan = ref
            .watch(driverPlanItemsProvider(vehicle.id))
            .valueOrNull ??
        const <DriverPlanItem>[];

    if (!_planSeeded) {
      _planSeeded = true;
      final requested = widget.initialPlanItemId;
      if (requested != null && plan.any((item) => item.id == requested)) {
        _planItemId = requested;
      }
      if (_odometer.text.isEmpty) _odometer.text = '${vehicle.mileage}';
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.driverRegisterServiceTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s3),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(s.driverRegisterBranchReport),
                icon: Icon(Icons.flag_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(s.driverRegisterBranchDoMyself),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {_doMyself},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _doMyself = selection.first),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: tokens.space.s1,
              bottom: tokens.space.s3,
            ),
            child: Text(
              _doMyself
                  ? s.driverRegisterBranchDoMyselfHint
                  : s.driverRegisterBranchReportHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
            ),
          ),
          _SectionLabel(s.driverRegisterItemLabel),
          DropdownButtonFormField<String?>(
            initialValue: _planItemId,
            decoration: InputDecoration(
              hintText: s.driverRegisterItemHint,
            ),
            items: [
              for (final item in plan)
                DropdownMenuItem(value: item.id, child: Text(item.name)),
              DropdownMenuItem(
                value: '',
                child: Text(s.driverRegisterFreeText),
              ),
            ],
            onChanged: (value) => setState(() {
              _planItemId = (value == null || value.isEmpty) ? null : value;
              if (_planItemId != null) _item.clear();
            }),
          ),
          if (_planItemId == null) ...[
            SizedBox(height: tokens.space.s2),
            DcoTextField(
              controller: _item,
              label: s.driverRegisterItemLabel,
              errorText: _errors['item'],
              textInputAction: TextInputAction.next,
            ),
          ],
          SizedBox(height: tokens.space.s2),
          Row(
            children: [
              Expanded(
                child: DcoTextField(
                  controller: _odometer,
                  label: s.driverRegisterOdometerLabel,
                  errorText: _errors['odometer'],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
              if (_doMyself) ...[
                SizedBox(width: tokens.space.s2),
                Expanded(
                  child: DcoTextField(
                    controller: _cost,
                    label: s.driverRegisterCostLabel,
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
            ],
          ),
          if (_doMyself) ...[
            SizedBox(height: tokens.space.s2),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color: tokens.icon.inactive,
                ),
                title: Text(s.driverRegisterDateLabel),
                subtitle: Text(DateFormat.yMMMd().format(_servicedOn)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _servicedOn,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _servicedOn = picked);
                },
              ),
            ),
          ],
          SizedBox(height: tokens.space.s2),
          DcoTextField(
            controller: _notes,
            label: _doMyself
                ? s.driverRegisterNotesLabel
                : s.fleetWoDescription,
            errorText: _doMyself ? null : _errors['description'],
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
          if (!_doMyself)
            Padding(
              padding: EdgeInsets.only(top: tokens.space.s1),
              child: Text(
                s.fleetWoDescriptionHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
              ),
            ),
          SizedBox(height: tokens.space.s5),
          DcoButton(
            label: _doMyself
                ? s.driverRegisterBranchDoMyself
                : s.driverRegisterBranchReport,
            loading: _saving,
            onPressed: () => _submit(orgCtx.id, vehicle.id),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s1),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.text.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

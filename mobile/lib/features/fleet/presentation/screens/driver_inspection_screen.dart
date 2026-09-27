import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Driver inspection flow: pick type + template, then work the checklist.
/// A failed required item surfaces as `failed` and auto-creates a work
/// order server-side.
class DriverInspectionScreen extends ConsumerStatefulWidget {
  const DriverInspectionScreen({super.key});

  @override
  ConsumerState<DriverInspectionScreen> createState() =>
      _DriverInspectionScreenState();
}

class _DriverInspectionScreenState
    extends ConsumerState<DriverInspectionScreen> {
  String _inspectionType = 'pre_trip';
  InspectionTemplate? _template;
  Inspection? _started;
  final _results = <String, bool>{}; // itemName → ok
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _start(String orgId, String vehicleId) async {
    final s = AppLocalizations.of(context)!;
    final template = _template;
    if (template == null) return;
    setState(() => _saving = true);
    try {
      final inspection = await ref.read(fleetRepositoryProvider).startInspection(
            orgId,
            vehicleId: vehicleId,
            templateId: template.id,
            inspectionType: _inspectionType,
          );
      setState(() {
        _started = inspection;
        _results
          ..clear()
          ..addEntries([
            for (final item in template.items) MapEntry(item.itemName, true),
          ]);
      });
      ref.invalidate(driverInspectionsProvider);
      ref.invalidate(orgInspectionsProvider(orgId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit(String orgId) async {
    final s = AppLocalizations.of(context)!;
    final template = _template;
    final inspection = _started;
    if (template == null || inspection == null) return;

    setState(() => _saving = true);
    try {
      final items = [
        for (final item in template.items)
          InspectionItemResult(
            itemName: item.itemName,
            result: (_results[item.itemName] ?? true) ? 'ok' : 'not_ok',
            photoMediaId: null,
            notes: null,
            required: item.required,
          ),
      ];
      final completed = await ref
          .read(fleetRepositoryProvider)
          .completeInspection(
            orgId,
            inspection.id,
            items: items,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.invalidate(driverInspectionsProvider);
      ref.invalidate(orgInspectionsProvider(orgId));
      if (!mounted) return;
      final failed = completed.status == 'failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed ? s.driverInspectionFailed : s.driverInspectionCompleted,
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
    final templates =
        orgCtx == null
            ? const <InspectionTemplate>[]
            : ref.watch(inspectionTemplatesProvider(orgCtx.id)).valueOrNull ??
                  const [];

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverInspectionStart)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    if (myVehicle?.hasAssignedVehicle != true) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverInspectionStart)),
        body: DcoEmptyState(
          title: s.driverNoVehicleTitle,
          body: s.driverNoVehicleBody,
        ),
      );
    }
    final vehicle = myVehicle!.vehicle!;

    // ── Stage 2: checklist ──
    if (_started != null) {
      final template = _template!;
      return Scaffold(
        appBar: AppBar(title: Text(s.driverInspectionStart)),
        body: ListView(
          padding: EdgeInsets.all(tokens.space.s3),
          children: [
            Text(
              '${vehicle.displayName} · '
              '${_inspectionType == 'post_trip' ? s.driverInspectionTypePost : s.driverInspectionTypePre}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.space.s3),
            for (final item in template.items)
              Card(
                margin: EdgeInsets.only(bottom: tokens.space.s2),
                child: SwitchListTile(
                  title: Text(item.itemName),
                  subtitle: item.required
                      ? Text(
                          s.driverInspectionRequired,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.caption),
                        )
                      : null,
                  value: _results[item.itemName] ?? true,
                  activeThumbColor: tokens.icon.active,
                  onChanged: (value) => setState(
                    () => _results[item.itemName] = value,
                  ),
                ),
              ),
            SizedBox(height: tokens.space.s2),
            DcoTextField(
              controller: _notes,
              label: s.driverInspectionNotes,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            SizedBox(height: tokens.space.s4),
            DcoButton(
              label: s.driverInspectionSubmit,
              loading: _saving,
              onPressed: () => _submit(orgCtx.id),
            ),
          ],
        ),
      );
    }

    // ── Stage 1: select ──
    return Scaffold(
      appBar: AppBar(title: Text(s.driverInspectionStart)),
      body: templates.isEmpty
          ? DcoEmptyState(
              title: s.driverInspectionNoTemplates,
              body: s.driverInspectionNoTemplatesBody,
            )
          : ListView(
              padding: EdgeInsets.all(tokens.space.s3),
              children: [
                Text(
                  vehicle.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.space.s3),
                DropdownButtonFormField<String>(
                  initialValue: _inspectionType,
                  decoration: InputDecoration(
                    labelText: s.driverInspectionType,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'pre_trip',
                      child: Text(s.driverInspectionTypePre),
                    ),
                    DropdownMenuItem(
                      value: 'post_trip',
                      child: Text(s.driverInspectionTypePost),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _inspectionType = v ?? 'pre_trip'),
                ),
                SizedBox(height: tokens.space.s3),
                DropdownButtonFormField<String>(
                  initialValue: _template?.id,
                  decoration: InputDecoration(
                    labelText: s.driverInspectionTemplateLabel,
                  ),
                  items: [
                    for (final template in templates)
                      DropdownMenuItem(
                        value: template.id,
                        child: Text(template.name),
                      ),
                  ],
                  onChanged: (v) => setState(
                    () => _template =
                        templates.where((t) => t.id == v).firstOrNull,
                  ),
                ),
                SizedBox(height: tokens.space.s5),
                DcoButton(
                  label: s.driverInspectionStart,
                  loading: _saving,
                  onPressed: _template == null
                      ? null
                      : () => _start(orgCtx.id, vehicle.id),
                ),
              ],
            ),
    );
  }
}

import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Report an issue on the assigned vehicle (creates a work order).
class DriverReportIssueScreen extends ConsumerStatefulWidget {
  const DriverReportIssueScreen({super.key});

  @override
  ConsumerState<DriverReportIssueScreen> createState() =>
      _DriverReportIssueScreenState();
}

class _DriverReportIssueScreenState
    extends ConsumerState<DriverReportIssueScreen> {
  final _odometer = TextEditingController();
  final _description = TextEditingController();

  final _errors = <String, String?>{};
  String _issueType = 'breakdown';
  String _urgency = 'medium';
  bool _saving = false;

  @override
  void dispose() {
    _odometer.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(String orgId, String vehicleId) async {
    final s = AppLocalizations.of(context)!;
    final odometer = int.tryParse(_odometer.text.trim());
    final description = _description.text.trim();
    setState(() {
      _errors
        ..['odometer'] = (odometer == null || odometer < 0)
            ? s.required
            : null
        ..['description'] = description.length < 10 ? s.required : null;
    });
    if (_errors.values.any((error) => error != null)) return;

    setState(() => _saving = true);
    try {
      await ref.read(fleetRepositoryProvider).createWorkOrder(
            orgId,
            vehicleId: vehicleId,
            odometerKm: odometer!,
            issueType: _issueType,
            description: description,
            urgency: _urgency,
          );
      ref.invalidate(driverWorkOrdersProvider);
      ref.invalidate(orgWorkOrdersProvider(orgId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fleetWoReported)));
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

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.fleetWoReportTitle)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    if (myVehicle?.hasAssignedVehicle != true) {
      return Scaffold(
        appBar: AppBar(title: Text(s.fleetWoReportTitle)),
        body: DcoEmptyState(
          title: s.driverNoVehicleTitle,
          body: s.driverNoVehicleBody,
        ),
      );
    }
    final vehicle = myVehicle!.vehicle!;

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetWoReportTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s3),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: tokens.space.s3),
            child: Text(
              '${s.fleetWoVehicle}: ${vehicle.displayName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          DcoTextField(
            controller: _odometer,
            label: s.fleetWoOdometerKm,
            errorText: _errors['odometer'],
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space.s3),
          DropdownButtonFormField<String>(
            initialValue: _issueType,
            decoration: InputDecoration(labelText: s.fleetWoIssueType),
            items: [
              for (final type in const [
                'breakdown',
                'accident',
                'wear_tear',
                'scheduled_service',
                'other',
              ])
                DropdownMenuItem(
                  value: type,
                  child: Text(issueTypeLabel(s, type)),
                ),
            ],
            onChanged: (v) => setState(() => _issueType = v ?? 'breakdown'),
          ),
          SizedBox(height: tokens.space.s3),
          DcoTextField(
            controller: _description,
            label: s.fleetWoDescription,
            hint: s.fleetWoDescriptionHint,
            errorText: _errors['description'],
            maxLines: 4,
            textInputAction: TextInputAction.newline,
          ),
          SizedBox(height: tokens.space.s3),
          DropdownButtonFormField<String>(
            initialValue: _urgency,
            decoration: InputDecoration(labelText: s.fleetWoUrgency),
            items: [
              for (final urgency in const ['low', 'medium', 'high', 'critical'])
                DropdownMenuItem(
                  value: urgency,
                  child: Text(urgencyLabel(s, urgency)),
                ),
            ],
            onChanged: (v) => setState(() => _urgency = v ?? 'medium'),
          ),
          SizedBox(height: tokens.space.s5),
          DcoButton(
            label: s.fleetWoReportSubmit,
            loading: _saving,
            onPressed: () => _submit(orgCtx.id, vehicle.id),
          ),
        ],
      ),
    );
  }
}

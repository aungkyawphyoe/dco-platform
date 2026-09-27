import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Transfer a showroom vehicle (status `reserved`) to a buyer account.
class FleetTransferScreen extends ConsumerStatefulWidget {
  const FleetTransferScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<FleetTransferScreen> createState() =>
      _FleetTransferScreenState();
}

class _FleetTransferScreenState extends ConsumerState<FleetTransferScreen> {
  final _buyerEmail = TextEditingController();
  final _mileage = TextEditingController();
  final _errors = <String, String?>{};

  DateTime? _saleDate;
  String? _warrantyTemplateId;
  bool _saving = false;

  @override
  void dispose() {
    _buyerEmail.dispose();
    _mileage.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = AppLocalizations.of(context)!;
    final email = _buyerEmail.text.trim();
    setState(() {
      _errors
        ..['email'] = (email.isEmpty || !email.contains('@')) ? s.required : null
        ..['date'] = _saleDate == null ? s.required : null
        ..['mileage'] = (int.tryParse(_mileage.text.trim()) == null)
            ? s.required
            : null;
    });
    if (_errors.values.any((error) => error != null)) return;

    final orgCtx = ref.read(entitlementsProvider).valueOrNull?.organization;
    if (orgCtx == null) return;
    final vehicles = ref.read(orgVehiclesProvider(orgCtx.id)).valueOrNull;
    final vehicle = vehicles?.where((v) => v.id == widget.vehicleId).firstOrNull;
    if (vehicle == null) return;

    final draft = VehicleTransferDraft(
      buyerEmail: email,
      saleDate: DateFormat('yyyy-MM-dd').format(_saleDate!),
      currentMileageKm: int.parse(_mileage.text.trim()),
      warrantyTemplateId: _warrantyTemplateId,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.fleetTransferTitle),
        content: Text(s.fleetTransferReviewBody(vehicle.displayName, email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.fleetTransferConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(fleetRepositoryProvider)
          .transferVehicle(orgCtx.id, widget.vehicleId, draft);
      ref.invalidate(orgVehiclesProvider(orgCtx.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fleetTransferSuccess)));
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
    final vehicles = orgCtx == null
        ? null
        : ref.watch(orgVehiclesProvider(orgCtx.id)).valueOrNull;
    final vehicle = vehicles
        ?.where((v) => v.id == widget.vehicleId)
        .firstOrNull;
    final templatesAsync = orgCtx == null
        ? null
        : ref.watch(warrantyTemplatesProvider(orgCtx.id));
    final templates = templatesAsync?.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetTransferTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s3),
        children: [
          if (vehicle != null)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space.s3),
              child: Text(
                vehicle.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          DcoTextField(
            controller: _buyerEmail,
            label: s.fleetTransferBuyerEmail,
            errorText: _errors['email'],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space.s2),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: tokens.icon.inactive,
              ),
              title: Text(s.fleetTransferSaleDate),
              subtitle: Text(
                _saleDate == null
                    ? '—'
                    : DateFormat.yMMMd().format(_saleDate!),
              ),
              trailing: _errors['date'] == null
                  ? null
                  : Icon(Icons.error, color: tokens.status.dangerFg),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _saleDate ?? now,
                  firstDate: DateTime(1900),
                  lastDate: now,
                );
                if (picked != null) setState(() => _saleDate = picked);
              },
            ),
          ),
          SizedBox(height: tokens.space.s2),
          DcoTextField(
            controller: _mileage,
            label: s.fleetTransferMileage,
            errorText: _errors['mileage'],
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: tokens.space.s3),
          DropdownButtonFormField<String?>(
            initialValue: _warrantyTemplateId,
            decoration: InputDecoration(
              labelText: s.fleetTransferWarranty,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(s.fleetTransferNoWarranty),
              ),
              for (final template in templates)
                DropdownMenuItem<String?>(
                  value: template.id,
                  child: Text(
                    '${template.name} · '
                    '${s.fleetWarrantyYearsKm(template.durationYears, template.mileageLimitKm)}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _warrantyTemplateId = v),
          ),
          SizedBox(height: tokens.space.s5),
          DcoButton(label: s.fleetTransferConfirm, loading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}

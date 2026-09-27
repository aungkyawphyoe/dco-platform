import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Create a warranty template (admin / manager).
class FleetWarrantyFormScreen extends ConsumerStatefulWidget {
  const FleetWarrantyFormScreen({super.key});

  @override
  ConsumerState<FleetWarrantyFormScreen> createState() =>
      _FleetWarrantyFormScreenState();
}

class _FleetWarrantyFormScreenState
    extends ConsumerState<FleetWarrantyFormScreen> {
  final _name = TextEditingController();
  final _years = TextEditingController();
  final _mileage = TextEditingController();
  final _coverage = TextEditingController();
  final _exclusions = TextEditingController();

  final _errors = <String, String?>{};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _years.dispose();
    _mileage.dispose();
    _coverage.dispose();
    _exclusions.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = AppLocalizations.of(context)!;
    final years = int.tryParse(_years.text.trim());
    final mileage = int.tryParse(_mileage.text.trim());
    setState(() {
      _errors
        ..['name'] = _name.text.trim().isEmpty ? s.required : null
        ..['years'] = (years == null || years < 1) ? s.required : null
        ..['mileage'] = (mileage == null || mileage < 0) ? s.required : null;
    });
    if (_errors.values.any((error) => error != null)) return;

    final orgCtx = ref.read(entitlementsProvider).valueOrNull?.organization;
    if (orgCtx == null) return;

    setState(() => _saving = true);
    try {
      final coverage = _coverage.text
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      await ref.read(fleetRepositoryProvider).createWarrantyTemplate(
            orgCtx.id,
            name: _name.text.trim(),
            durationYears: years!,
            mileageLimitKm: mileage!,
            coverageCategories: coverage,
            exclusions: _exclusions.text.trim().isEmpty
                ? null
                : _exclusions.text.trim(),
          );
      ref.invalidate(warrantyTemplatesProvider(orgCtx.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fleetWarrantyCreated)));
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

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetWarrantyFormTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s3),
        children: [
          DcoTextField(
            controller: _name,
            label: s.fleetWarrantyName,
            hint: s.fleetWarrantyNameHint,
            errorText: _errors['name'],
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space.s2),
          Row(
            children: [
              Expanded(
                child: DcoTextField(
                  controller: _years,
                  label: s.fleetWarrantyDuration,
                  errorText: _errors['years'],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: DcoTextField(
                  controller: _mileage,
                  label: s.fleetWarrantyMileageLimit,
                  errorText: _errors['mileage'],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space.s2),
          DcoTextField(
            controller: _coverage,
            label: s.fleetWarrantyCoverage,
            hint: s.fleetWarrantyCoverageHint,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space.s2),
          DcoTextField(
            controller: _exclusions,
            label: s.fleetWarrantyExclusions,
            hint: s.fleetWarrantyExclusionsHint,
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: tokens.space.s5),
          DcoButton(label: s.save, loading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}

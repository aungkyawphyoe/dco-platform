import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/parts/domain/entities/part.dart';
import 'package:dco_mobile/features/parts/domain/part_failure.dart';
import 'package:dco_mobile/features/parts/domain/part_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PartFormScreen extends ConsumerStatefulWidget {
  const PartFormScreen({super.key, this.partId});

  final String? partId;

  bool get isEditing => partId != null;

  @override
  ConsumerState<PartFormScreen> createState() => _PartFormScreenState();
}

class _PartFormScreenState extends ConsumerState<PartFormScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _partNumber = TextEditingController();
  final _notes = TextEditingController();
  final _errors = <String, String?>{};

  String? _formError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.partId == null) {
      setState(() => _loading = false);
      return;
    }
    final part = await ref.read(partsRepositoryProvider).getById(widget.partId!);
    if (!mounted) return;
    if (part != null) {
      _name.text = part.name;
      _brand.text = part.brand ?? '';
      _partNumber.text = part.partNumber ?? '';
      _notes.text = part.notes ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _partNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  PartDraft? _draftOrNull() {
    setState(() {
      _errors
        ..['name'] = PartValidators.name(_name.text)
        ..['brand'] = PartValidators.brand(_brand.text)
        ..['number'] = PartValidators.partNumber(_partNumber.text)
        ..['notes'] = PartValidators.notes(_notes.text);
      _formError = null;
    });
    if (_errors.values.any((error) => error != null)) return null;
    return PartDraft(
      name: _name.text,
      brand: _brand.text,
      partNumber: _partNumber.text,
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
      final repo = ref.read(partsRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(userId: vehicle.userId, partId: widget.partId!, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.partUpdated);
      } else {
        await repo.add(userId: vehicle.userId, vehicleId: vehicle.id, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.partAdded);
      }
      if (mounted) context.pop();
    } on PartFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit Part' : 'Add Part')),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Part' : 'Add Part')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                DcoTextField(
                  key: const Key('part-name'),
                  label: 'Name *',
                  controller: _name,
                  hint: 'Oil filter',
                  errorText: _errors['name'],
                  maxLength: PartValidators.maxNameLength,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['name'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'Brand',
                  controller: _brand,
                  hint: 'Bosch',
                  errorText: _errors['brand'],
                  maxLength: PartValidators.maxBrandLength,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['brand'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'Part number',
                  controller: _partNumber,
                  hint: 'OF-1234',
                  errorText: _errors['number'],
                  maxLength: PartValidators.maxPartNumberLength,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['number'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  label: 'Notes',
                  controller: _notes,
                  hint: 'Size, source, or fitment',
                  errorText: _errors['notes'],
                  maxLength: PartValidators.maxNotesLength,
                  maxLines: 4,
                  minLines: 3,
                  onChanged: (_) => setState(() => _errors['notes'] = null),
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
                    key: const Key('part-save'),
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

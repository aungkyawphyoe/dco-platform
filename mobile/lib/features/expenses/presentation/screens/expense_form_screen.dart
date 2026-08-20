import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/domain/expense_failure.dart';
import 'package:dco_mobile/features/expenses/domain/expense_validators.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/parts/domain/entities/part.dart';
import 'package:dco_mobile/features/parts/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expenseId});

  final String? expenseId;

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _categoryLabel = TextEditingController();
  final _amount = TextEditingController();
  final _date = TextEditingController();
  final _notes = TextEditingController();
  final _errors = <String, String?>{};
  final _parts = <ExpenseAssignedPartDraft>[];

  ExpenseCategory? _category;
  DateTime _incurredOn = DateTime.now();
  String? _receiptPath;
  String? _receiptMediaId;
  String? _formError;
  bool _loading = true;
  bool _saving = false;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _date.text = DateFormat.yMMMd().format(_incurredOn);
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.expenseId != null) {
      final expense = await ref.read(expenseRepositoryProvider).getById(widget.expenseId!);
      if (expense != null && mounted) {
        _category = expense.category;
        _categoryLabel.text = expense.category.label;
        _amount.text = _formatNumber(expense.amount);
        _incurredOn = expense.incurredOn;
        _date.text = DateFormat.yMMMd().format(expense.incurredOn);
        _notes.text = expense.notes ?? '';
        _receiptPath = expense.receiptLocalPath;
        _receiptMediaId = expense.receiptMediaId;
        _parts
          ..clear()
          ..addAll(
            expense.parts.map(
              (part) => ExpenseAssignedPartDraft(partId: part.partId, name: part.name),
            ),
          );
      } else if (mounted) {
        _missing = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _categoryLabel.dispose();
    _amount.dispose();
    _date.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  ExpenseDraft? _draftOrNull() {
    setState(() {
      _errors
        ..['category'] = ExpenseValidators.category(_category)
        ..['amount'] = ExpenseValidators.amount(_amount.text)
        ..['date'] = ExpenseValidators.date(_incurredOn, now: DateTime.now())
        ..['notes'] = ExpenseValidators.notes(_notes.text);
      _formError = null;
    });
    if (_errors.values.any((error) => error != null)) return null;
    return ExpenseDraft(
      category: _category!,
      amount: ExpenseValidators.parseDecimal(_amount.text)!,
      incurredOn: _incurredOn,
      notes: _notes.text,
      receiptLocalPath: _receiptPath,
      receiptMediaId: _receiptMediaId,
      parts: List.of(_parts),
    );
  }

  Future<void> _save() async {
    final draft = _draftOrNull();
    if (draft == null) return;
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(expenseRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(
          userId: vehicle.userId,
          expenseId: widget.expenseId!,
          draft: draft,
        );
        ref.read(analyticsProvider).track(AnalyticsEvent.expenseUpdated);
      } else {
        await repo.add(
          userId: vehicle.userId,
          vehicleId: vehicle.id,
          draft: draft,
        );
        ref.read(analyticsProvider).track(AnalyticsEvent.expenseAdded);
      }
      if (mounted) context.pop();
    } on ExpenseFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null || widget.expenseId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this expense?'),
          content: const Text('This removes the entry and its receipt photo. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepositoryProvider).delete(
        userId: vehicle.userId,
        expenseId: widget.expenseId!,
      );
      ref.read(analyticsProvider).track(AnalyticsEvent.expenseDeleted);
      if (mounted) context.pop();
    } on ExpenseFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final initial = _incurredOn.isAfter(lastDate) ? lastDate : _incurredOn;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: lastDate,
    );
    if (picked == null) return;
    setState(() {
      _incurredOn = picked;
      _date.text = DateFormat.yMMMd().format(picked);
      _errors['date'] = null;
    });
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<ExpenseCategory>(
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
                child: Text('Category', style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final category in ExpenseCategory.values)
                ListTile(
                  title: Text(category.label),
                  trailing: category == _category ? Icon(Icons.check, color: tokens.text.accent) : null,
                  onTap: () => Navigator.pop(context, category),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _category = selected;
      _categoryLabel.text = selected.label;
      _errors['category'] = null;
    });
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final dest = File('${directory.path}/expenses/${const Uuid().v4()}.jpg');
      await dest.parent.create(recursive: true);
      await File(picked.path).copy(dest.path);
      if (!mounted) return;
      setState(() {
        _receiptPath = dest.path;
        _receiptMediaId = const Uuid().v4();
        _formError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'Camera or photo access was denied. You can save without a photo.';
      });
    }
  }

  Future<void> _chooseReceiptSource() async {
    final tokens = context.tokens;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.background.card,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: tokens.icon.active),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickReceipt(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: tokens.icon.active),
                title: const Text('Photo library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickReceipt(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAssignPart() async {
    final catalog = ref.read(vehiclePartsProvider).valueOrNull ?? const <Part>[];
    final assigned = _parts.map((part) => part.partId).toSet();
    final available = catalog.where((part) => !assigned.contains(part.id)).toList();
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
              Text('Assign part', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.space.s3),
              if (catalog.isEmpty)
                Text(
                  'No parts in the catalog yet. Add one, then assign it here.',
                  style: TextStyle(color: tokens.text.caption),
                )
              else if (available.isEmpty)
                Text(
                  'Every part is already assigned to this expense.',
                  style: TextStyle(color: tokens.text.caption),
                )
              else
                ...available.map(
                  (part) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(part.name),
                    subtitle: part.detailLine == null ? null : Text(part.detailLine!),
                    onTap: () {
                      setState(() {
                        _parts.add(ExpenseAssignedPartDraft(partId: part.id, name: part.name));
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              SizedBox(height: tokens.space.s3),
              DcoButton(
                label: 'Add a new part',
                variant: DcoButtonVariant.secondary,
                onPressed: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.partNew);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final currency = ref.watch(userPreferencesProvider).valueOrNull?.currency.code ?? 'USD';
    ref.watch(vehiclePartsProvider);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit expense' : 'Add expense')),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit expense' : 'Add expense')),
        body: const DcoEmptyState(
          title: 'No active vehicle',
          body: 'Register a vehicle to log spend.',
        ),
      );
    }

    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit expense')),
        body: const DcoEmptyState(
          title: 'Expense not found',
          body: 'It may have been deleted.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit expense' : 'Add expense')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                Text(
                  vehicle.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('expense-category'),
                  label: 'Category *',
                  controller: _categoryLabel,
                  readOnly: true,
                  hint: 'Choose a category',
                  onTap: _pickCategory,
                  errorText: _errors['category'],
                  suffix: Icon(Icons.expand_more, color: tokens.icon.inactive),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('expense-amount'),
                  label: 'Amount *',
                  controller: _amount,
                  hint: currency,
                  errorText: _errors['amount'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _errors['amount'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('expense-date'),
                  label: 'Date *',
                  controller: _date,
                  readOnly: true,
                  onTap: _pickDate,
                  errorText: _errors['date'],
                  suffix: Icon(Icons.calendar_today_outlined, color: tokens.icon.inactive),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('expense-notes'),
                  label: 'Notes',
                  controller: _notes,
                  hint: 'Optional',
                  maxLength: ExpenseValidators.maxNotesLength,
                  maxLines: 3,
                  minLines: 2,
                  errorText: _errors['notes'],
                  onChanged: (_) => setState(() => _errors['notes'] = null),
                ),
                SizedBox(height: tokens.space.s5),
                Text('Receipt', style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s3),
                _ReceiptPicker(
                  path: _receiptPath,
                  onAdd: _chooseReceiptSource,
                  onRemove: () => setState(() {
                    _receiptPath = null;
                    _receiptMediaId = null;
                  }),
                ),
                SizedBox(height: tokens.space.s5),
                Text('Parts', style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s3),
                ..._parts.map(
                  (part) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.space.s3),
                    child: Material(
                      color: tokens.background.card,
                      borderRadius: BorderRadius.circular(tokens.radius.md),
                      child: Padding(
                        padding: EdgeInsets.all(tokens.space.s3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(part.name, style: Theme.of(context).textTheme.titleMedium),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => setState(() => _parts.remove(part)),
                              icon: Icon(Icons.close, color: tokens.icon.inactive),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openAssignPart,
                  icon: Icon(Icons.add, color: tokens.icon.active),
                  label: Text('assign part', style: TextStyle(color: tokens.text.link)),
                ),
                if (_formError != null) ...[
                  SizedBox(height: tokens.space.s4),
                  Text(_formError!, style: TextStyle(color: tokens.status.dangerFg)),
                ],
                if (widget.isEditing) ...[
                  SizedBox(height: tokens.space.s5),
                  DcoButton(
                    key: const Key('expense-delete'),
                    label: 'Delete expense',
                    variant: DcoButtonVariant.destructive,
                    onPressed: _saving ? null : _delete,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space.s4,
              tokens.space.s3,
              tokens.space.s4,
              tokens.space.s4,
            ),
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
                    key: const Key('expense-save'),
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

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.path,
    required this.onAdd,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (path == null) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.photo_outlined, color: tokens.icon.active),
        label: Text('Add receipt photo', style: TextStyle(color: tokens.text.link)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radius.md),
          child: Image.file(
            File(path!),
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: tokens.space.s2),
        Row(
          children: [
            TextButton(
              onPressed: onAdd,
              child: Text('Replace', style: TextStyle(color: tokens.text.link)),
            ),
            TextButton(
              onPressed: onRemove,
              child: Text('Remove', style: TextStyle(color: tokens.status.dangerFg)),
            ),
          ],
        ),
      ],
    );
  }
}

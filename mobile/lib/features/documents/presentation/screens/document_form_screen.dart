import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/domain/document_failure.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class DocumentFormScreen extends ConsumerStatefulWidget {
  const DocumentFormScreen({super.key, this.documentId});

  final String? documentId;

  bool get isEditing => documentId != null;

  @override
  ConsumerState<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _categoryLabel = TextEditingController();
  final _errors = <String, String?>{};

  DocumentCategory? _category;
  String? _localFilePath;
  String? _formError;
  bool _loading = true;
  bool _saving = false;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.documentId != null) {
      final doc = await ref
          .read(documentRepositoryProvider)
          .getById(widget.documentId!);
      if (doc != null && mounted) {
        _name.text = doc.name;
        _category = doc.category;
        _categoryLabel.text = _categoryLabelFor(doc.category);
        _notes.text = doc.notes ?? '';
        _localFilePath = doc.localFilePath;
      } else if (mounted) {
        _missing = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _categoryLabel.dispose();
    super.dispose();
  }

  DocumentDraft? _draftOrNull() {
    setState(() {
      _errors
        ..['name'] = _validateName(_name.text)
        ..['category'] = _category == null ? 'Required' : null;
      _formError = null;
    });
    if (_errors.values.any((error) => error != null)) return null;
    return DocumentDraft(
      name: _name.text.trim(),
      category: _category!,
      notes: _notes.text,
      localFilePath: _localFilePath,
    );
  }

  Future<void> _save() async {
    final draft = _draftOrNull();
    if (draft == null) return;
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(
          userId: vehicle.userId,
          documentId: widget.documentId!,
          draft: draft,
        );
      } else {
        await repo.add(
          userId: vehicle.userId,
          vehicleId: vehicle.id,
          draft: draft,
        );
        ref.read(analyticsProvider).track(AnalyticsEvent.documentUploaded);
      }
      if (mounted) context.pop();
    } on DocumentFailure catch (failure) {
      if (mounted) {
        setState(() => _formError = switch (failure) {
              DocumentValidationFailure(:final message) => message,
              DocumentTooLargeFailure() => 'File is too large',
              DocumentNotFoundFailure() => 'Document not found',
            });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final vehicle = ref.read(activeVehicleProvider).valueOrNull;
    if (vehicle == null || widget.documentId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final s = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(s.documentFormDeleteTitle),
          content: Text(s.documentFormDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(documentRepositoryProvider).delete(
            userId: vehicle.userId,
            documentId: widget.documentId!,
          );
      ref.read(analyticsProvider).track(AnalyticsEvent.documentDeleted);
      if (mounted) context.pop();
    } on DocumentFailure catch (failure) {
      if (mounted) setState(() => _formError = switch (failure) {
            DocumentValidationFailure(:final message) => message,
            DocumentTooLargeFailure() => 'File is too large',
            DocumentNotFoundFailure() => 'Document not found',
          });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickFile() async {
    final tokens = context.tokens;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.background.card,
      builder: (context) {
        final s = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    Icon(Icons.photo_camera_outlined, color: tokens.icon.active),
                title: Text(s.documentFormCameraOption),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: tokens.icon.active),
                title: Text(s.documentFormGalleryOption),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined,
                    color: tokens.icon.active),
                title: Text(s.documentFormPdfOption),
                onTap: () {
                  Navigator.pop(context);
                  _pickPdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final dest = File('${directory.path}/documents/${const Uuid().v4()}.jpg');
      await dest.parent.create(recursive: true);
      await File(picked.path).copy(dest.path);
      if (!mounted) return;
      setState(() {
        _localFilePath = dest.path;
        _formError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = AppLocalizations.of(context)!.documentFormPickError;
      });
    }
  }

  Future<void> _pickPdf() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final dest = File('${directory.path}/documents/${const Uuid().v4()}.pdf');
      await dest.parent.create(recursive: true);
      await File(picked.path).copy(dest.path);
      if (!mounted) return;
      setState(() {
        _localFilePath = dest.path;
        _formError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = AppLocalizations.of(context)!.documentFormPickError;
      });
    }
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<DocumentCategory>(
      context: context,
      backgroundColor: context.tokens.background.card,
      builder: (context) {
        final tokens = context.tokens;
        final s = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    tokens.space.s4, tokens.space.s4, tokens.space.s4, tokens.space.s2),
                child: Text(
                  s.documentFormCategorySheetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final category in DocumentCategory.values)
                ListTile(
                  title: Text(_categoryLabelFor(category)),
                  trailing: category == _category
                      ? Icon(Icons.check, color: tokens.text.accent)
                      : null,
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
      _categoryLabel.text = _categoryLabelFor(selected);
      _errors['category'] = null;
    });
  }

  String? _validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Required';
    if (trimmed.length > 120) return 'Must be 120 characters or less';
    return null;
  }

  String _categoryLabelFor(DocumentCategory category) => switch (category) {
        DocumentCategory.insurance => 'Insurance',
        DocumentCategory.registration => 'Registration',
        DocumentCategory.invoice => 'Invoice',
        DocumentCategory.warranty => 'Warranty',
        DocumentCategory.receipt => 'Receipt',
        DocumentCategory.other => 'Other',
      };

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isEditing ? s.documentFormEditTitle : s.documentFormAddTitle)),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isEditing ? s.documentFormEditTitle : s.documentFormAddTitle)),
        body: DcoEmptyState(
          title: s.documentsNoActiveVehicle,
          body: s.documentFormNoActiveVehicleBody,
        ),
      );
    }

    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: Text(s.documentFormEditTitle)),
        body: DcoEmptyState(
          title: s.documentFormNotFound,
          body: s.documentFormNotFoundBody,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isEditing ? s.documentFormEditTitle : s.documentFormAddTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                Text(
                  vehicle.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: tokens.text.caption),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('document-name'),
                  label: s.documentFormName,
                  controller: _name,
                  hint: s.documentFormNameHint,
                  errorText: _errors['name'],
                  onChanged: (_) => setState(() => _errors['name'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('document-category'),
                  label: s.documentFormCategory,
                  controller: _categoryLabel,
                  readOnly: true,
                  hint: s.documentFormCategoryHint,
                  onTap: _pickCategory,
                  errorText: _errors['category'],
                  suffix: Icon(Icons.expand_more, color: tokens.icon.inactive),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('document-notes'),
                  label: s.documentFormNotes,
                  controller: _notes,
                  hint: s.documentFormNotesHint,
                  maxLines: 3,
                  minLines: 2,
                ),
                SizedBox(height: tokens.space.s5),
                Text(s.documentFormFileSection,
                    style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: tokens.space.s3),
                _FilePicker(
                  path: _localFilePath,
                  onAdd: _pickFile,
                  onRemove: () => setState(() {
                    _localFilePath = null;
                  }),
                ),
                if (_formError != null) ...[
                  SizedBox(height: tokens.space.s4),
                  Text(_formError!,
                      style: TextStyle(color: tokens.status.dangerFg)),
                ],
                if (widget.isEditing) ...[
                  SizedBox(height: tokens.space.s5),
                  DcoButton(
                    key: const Key('document-delete'),
                    label: s.documentFormDeleteButton,
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
                    label: s.cancel,
                    variant: DcoButtonVariant.secondary,
                    onPressed: () => context.pop(),
                  ),
                ),
                SizedBox(width: tokens.space.s3),
                Expanded(
                  child: DcoButton(
                    key: const Key('document-save'),
                    label: s.save,
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

class _FilePicker extends StatelessWidget {
  const _FilePicker({
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
    final s = AppLocalizations.of(context)!;
    if (path == null) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.attach_file_outlined, color: tokens.icon.active),
        label:
            Text(s.documentFormAttachFile, style: TextStyle(color: tokens.text.link)),
      );
    }
    final isImage = path!.endsWith('.jpg') ||
        path!.endsWith('.jpeg') ||
        path!.endsWith('.png');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radius.md),
            child: Image.file(
              File(path!),
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            padding: EdgeInsets.all(tokens.space.s3),
            decoration: BoxDecoration(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined,
                    color: tokens.status.dangerFg, size: 32),
                SizedBox(width: tokens.space.s3),
                Expanded(
                  child: Text(
                    path!.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: tokens.space.s2),
        Row(
          children: [
            TextButton(
              onPressed: onAdd,
              child: Text(s.documentFormReplace,
                  style: TextStyle(color: tokens.text.link)),
            ),
            TextButton(
              onPressed: onRemove,
              child: Text(s.remove,
                  style: TextStyle(color: tokens.status.dangerFg)),
            ),
          ],
        ),
      ],
    );
  }
}

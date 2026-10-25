import 'dart:io';

import 'package:dco_mobile/core/media/media_api.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/garage/access_provider.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A draft attachment editor. File bytes stay local until the enclosing form
/// saves; linking existing files never makes another copy.
class LogAttachments extends ConsumerStatefulWidget {
  const LogAttachments({
    super.key,
    required this.kind,
    required this.category,
    required this.vehicleId,
    required this.onChanged,
    this.recordId,
    this.readOnly = false,
  });
  final String kind;
  final DocumentCategory category;
  final String vehicleId;
  final String? recordId;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  ConsumerState<LogAttachments> createState() => LogAttachmentsState();
}

class LogAttachmentsState extends ConsumerState<LogAttachments> {
  final List<DocumentDraft> _files = [];
  final Map<String, Document> _selected = {};
  final Set<String> _removed = {};
  bool _saved = false;
  String? _error;

  bool get hasChanges =>
      _files.isNotEmpty || _selected.isNotEmpty || _removed.isNotEmpty;
  bool _isLinked(Document doc) => doc.links.any(
    (link) => link.kind == widget.kind && link.recordId == widget.recordId,
  );

  void markSaved() => _saved = true;

  Future<void> save(String userId, String recordId) async {
    final repo = ref.read(documentRepositoryProvider);
    final target = DocumentLink(kind: widget.kind, recordId: recordId);
    for (final id in {..._selected.keys, ..._removed}) {
      final doc = await repo.getById(id);
      if (doc == null) throw StateError('An attachment is no longer available');
      final links = doc.links.where((link) => !link.matches(target)).toList();
      if (!_removed.contains(id)) links.add(target);
      await repo.update(
        userId: userId,
        documentId: id,
        draft: DocumentDraft(
          name: doc.name,
          category: doc.category,
          notes: doc.notes,
          expiresOn: doc.expiresOn,
          localFilePath: doc.localFilePath,
          links: links,
        ),
      );
    }
    for (final draft in _files) {
      await repo.add(
        userId: userId,
        vehicleId: widget.vehicleId,
        draft: DocumentDraft(
          name: draft.name,
          category: draft.category,
          localFilePath: draft.localFilePath,
          links: [target],
        ),
      );
    }
  }

  Future<bool> confirmDiscard() async {
    if (!hasChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved attachments?'),
            content: const Text(
              'New files will be discarded. Existing documents will remain in Documents.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    if (!_saved)
      for (final draft in _files) {
        _removeFile(draft.localFilePath);
      }
    super.dispose();
  }

  Future<void> _removeFile(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      /* Already removed. */
    }
  }

  bool _canChange(Document doc) {
    final vehicle = ref.read(vehicleByIdProvider(widget.vehicleId)).valueOrNull;
    final access = ref.read(vehicleAccessProvider(vehicle));
    final org = ref.read(driverOrganizationIdProvider);
    return !widget.readOnly &&
        (access.isOwner || org != null) &&
        access.canEditRecord(doc.createdBy) &&
        !(ref.read(recordAdminLockProvider('document:${doc.id}')).valueOrNull ??
            org != null);
  }

  Future<void> _pick(String source) async {
    try {
      String? path;
      String extension;
      if (source == 'pdf') {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        path = files.isEmpty ? null : files.single.path;
        extension = 'pdf';
      } else {
        final image = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2400,
          maxHeight: 2400,
        );
        path = image?.path;
        extension = 'jpg';
      }
      if (path == null) return;
      if (await File(path).length() > MediaApi.maxBytes)
        throw StateError('File exceeds the 15 MB limit');
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/documents/${const Uuid().v4()}.$extension',
      );
      await file.parent.create(recursive: true);
      await File(path).copy(file.path);
      if (!mounted) {
        await _removeFile(file.path);
        return;
      }
      setState(() {
        _error = null;
        _files.add(
          DocumentDraft(
            name:
                '${widget.category == DocumentCategory.invoice ? 'Invoice' : 'Receipt'} ${_files.length + 1}',
            category: widget.category,
            localFilePath: file.path,
          ),
        );
      });
      widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _editDraft(DocumentDraft draft) async {
    final name = TextEditingController(text: draft.name);
    var category = draft.category;
    final updated = await showDialog<DocumentDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Attachment details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              DropdownButton<DocumentCategory>(
                value: category,
                isExpanded: true,
                items: DocumentCategory.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => category = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty)
                  Navigator.pop(
                    context,
                    DocumentDraft(
                      name: name.text.trim(),
                      category: category,
                      localFilePath: draft.localFilePath,
                    ),
                  );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (updated == null || !mounted) return;
    setState(() => _files[_files.indexOf(draft)] = updated);
    widget.onChanged();
  }

  Future<void> _chooseExisting(List<Document> documents) async {
    final candidates = documents
        .where(
          (doc) =>
              (!_isLinked(doc) || _removed.contains(doc.id)) &&
              !_selected.containsKey(doc.id) &&
              _canChange(doc),
        )
        .toList();
    final picked = await showModalBottomSheet<Document>(
      context: context,
      builder: (context) => SafeArea(
        child: candidates.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No other documents are available for this vehicle.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: candidates
                    .map(
                      (doc) => ListTile(
                        title: Text(doc.name),
                        subtitle: Text(doc.category.name),
                        onTap: () => Navigator.pop(context, doc),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected[picked.id] = picked;
      _removed.remove(picked.id);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final documents =
        ref.watch(documentsForVehicleProvider(widget.vehicleId)).valueOrNull ??
        [];
    final existing = {
      ...{for (final doc in documents.where(_isLinked)) doc.id: doc},
      ..._selected,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
        const Text(
          'Images or PDF · up to 15 MB each. Files also appear in Documents.',
        ),
        for (final doc in existing.values.where(
          (doc) => !_removed.contains(doc.id),
        ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(doc.name),
            onTap: () => context.push(AppRoutes.documentView(doc.id)),
            trailing: !_canChange(doc)
                ? const Icon(Icons.lock_outline)
                : IconButton(
                    tooltip: 'Remove from this log',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selected.remove(doc.id);
                        if (_isLinked(doc)) _removed.add(doc.id);
                      });
                      widget.onChanged();
                    },
                  ),
          ),
        for (final draft in _files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(draft.name),
            subtitle: Text('${draft.category.name} · Not saved yet'),
            onTap: () => _editDraft(draft),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Discard file',
              onPressed: () {
                setState(() => _files.remove(draft));
                _removeFile(draft.localFilePath);
                widget.onChanged();
              },
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!widget.readOnly)
          Wrap(
            spacing: 8,
            children: [
              PopupMenuButton<String>(
                onSelected: _pick,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'camera', child: Text('Take photo')),
                  PopupMenuItem(value: 'gallery', child: Text('Choose image')),
                  PopupMenuItem(value: 'pdf', child: Text('Choose PDF')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Upload file'),
                ),
              ),
              TextButton(
                onPressed: () => _chooseExisting(documents),
                child: const Text('Choose from Documents'),
              ),
            ],
          ),
      ],
    );
  }
}

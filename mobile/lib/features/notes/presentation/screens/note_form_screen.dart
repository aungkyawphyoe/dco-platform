import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/notes/domain/entities/note.dart';
import 'package:dco_mobile/features/notes/domain/note_failure.dart';
import 'package:dco_mobile/features/notes/domain/note_validators.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NoteFormScreen extends ConsumerStatefulWidget {
  const NoteFormScreen({super.key, this.noteId});

  final String? noteId;

  bool get isEditing => noteId != null;

  @override
  ConsumerState<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends ConsumerState<NoteFormScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _errors = <String, String?>{};

  String? _formError;
  Note? _note;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.noteId == null) {
      setState(() => _loading = false);
      return;
    }
    final note = await ref
        .read(notesRepositoryProvider)
        .getById(widget.noteId!);
    if (!mounted) return;
    if (note != null) {
      _note = note;
      _title.text = note.title;
      _body.text = note.body;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  NoteDraft? _draftOrNull() {
    setState(() {
      _errors['title'] = NoteValidators.title(_title.text);
      _errors['body'] = NoteValidators.draft(
        title: _title.text,
        body: _body.text,
      );
      _formError = null;
    });
    if (_errors.values.any((error) => error != null)) return null;
    return NoteDraft(title: _title.text, body: _body.text);
  }

  Future<void> _save() async {
    final draft = _draftOrNull();
    if (draft == null) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(userId: userId, noteId: widget.noteId!, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.noteUpdated);
      } else {
        await repo.add(userId: userId, draft: draft);
        ref.read(analyticsProvider).track(AnalyticsEvent.noteAdded);
      }
      if (mounted) context.pop();
    } on NoteFailure catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final note = _note;
    final userId = ref.read(currentUserIdProvider);
    if (note == null || userId == null) return;
    final s = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(notesRepositoryProvider);
    try {
      await repo.delete(userId: userId, noteId: note.id);
    } on NoteFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return;
    }
    ref.read(analyticsProvider).track(AnalyticsEvent.noteDeleted);
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.noteDeleted),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: s.noteUndo,
          textColor: DcoTokens.garageMinimalDark.text.primary,
          onPressed: () {
            repo.restore(note);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing ? s.noteFormEditTitle : s.noteFormAddTitle,
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? s.noteFormEditTitle : s.noteFormAddTitle,
        ),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: s.noteDelete,
              onPressed: _delete,
              icon: Icon(Icons.delete_outline, color: tokens.status.dangerFg),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                DcoTextField(
                  key: const Key('note-title'),
                  label: s.noteFormTitle,
                  controller: _title,
                  hint: s.noteFormTitleHint,
                  errorText: _errors['title'],
                  maxLength: NoteValidators.maxTitleLength,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _errors['title'] = null),
                ),
                SizedBox(height: tokens.space.s4),
                DcoTextField(
                  key: const Key('note-body'),
                  label: s.noteFormBody,
                  controller: _body,
                  hint: s.noteFormBodyHint,
                  errorText: _errors['body'],
                  maxLines: 16,
                  minLines: 8,
                  onChanged: (_) => setState(() => _errors['body'] = null),
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
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space.s5,
              tokens.space.s3,
              tokens.space.s5,
              tokens.space.s5,
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
                    key: const Key('note-save'),
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

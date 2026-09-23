import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/notes/domain/entities/note.dart';
import 'package:dco_mobile/features/notes/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final notes = ref.watch(userNotesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.notesTitle)),
      body: Stack(
        children: [
          notes.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: tokens.text.accent),
            ),
            error: (error, _) =>
                DcoEmptyState(title: s.notesLoadError, body: '$error'),
            data: (items) {
              if (items.isEmpty) {
                return DcoEmptyState(
                  title: s.notesEmptyTitle,
                  body: s.notesEmptyBody,
                  actionLabel: s.notesNewNote,
                  actionKey: const Key('notes-empty-cta'),
                  onAction: () => context.push(AppRoutes.noteNew),
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                padding: EdgeInsets.fromLTRB(
                  tokens.space.s4,
                  tokens.space.s3,
                  tokens.space.s4,
                  96,
                ),
                mainAxisSpacing: tokens.space.s3,
                crossAxisSpacing: tokens.space.s3,
                childAspectRatio: 0.78,
                children: [
                  for (final note in items)
                    _NoteCard(
                      note: note,
                      untitledLabel: s.noteUntitled,
                      onTap: () => context.push(AppRoutes.noteEdit(note.id)),
                    ),
                ],
              );
            },
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SizedBox(
              width: 150,
              height: 56,
              child: FloatingActionButton.extended(
                backgroundColor: tokens.button.primary.background,
                foregroundColor: tokens.text.inverse,
                onPressed: () => context.push(AppRoutes.noteNew),
                label: Text(s.notesNewNote),
                icon: const Icon(Icons.add),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radius.full),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.untitledLabel,
    required this.onTap,
  });

  final Note note;
  final String untitledLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = note.isUntitled ? untitledLabel : note.displayTitle;
    final hasTitle = !note.isUntitled;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        boxShadow: tokens.shadows.card,
      ),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          child: Padding(
            padding: EdgeInsets.all(tokens.space.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: hasTitle
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.text.caption,
                          fontStyle: FontStyle.italic,
                        ),
                ),
                if (note.body.trim().isNotEmpty) ...[
                  SizedBox(height: tokens.space.s2),
                  Expanded(
                    child: Text(
                      note.body,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.secondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

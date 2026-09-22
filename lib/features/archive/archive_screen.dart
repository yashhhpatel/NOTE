import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../shared/utils/snackbars.dart';
import '../../shared/widgets/empty_state.dart';
import '../notes/notes_providers.dart';
import '../notes/widgets/note_card.dart';

/// Lists archived notes. Long-press a note to unarchive or delete it.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(archivedNotesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Archive'),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load archive: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return const EmptyState(
              icon: Icons.archive_outlined,
              title: 'No archived notes',
              message: 'Archived notes are kept here and can be restored.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final card = notes[i];
              final repo = ref.read(notesRepositoryProvider);
              return NoteCardTile(
                card: card,
                onTap: () => context.push(
                  card.isChecklist
                      ? Routes.checklist(card.note.id)
                      : Routes.textNote(card.note.id),
                ),
                onLongPress: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (sheetContext) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.unarchive_outlined),
                          title: const Text('Unarchive'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            repo.setArchived(card.note.id, false);
                            showUndoSnackBar(
                              context,
                              message: 'Unarchived',
                              onUndo: () =>
                                  repo.setArchived(card.note.id, true),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: const Text('Move to trash'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            repo.moveToTrash(card.note.id);
                            showUndoSnackBar(
                              context,
                              message: 'Moved to trash',
                              onUndo: () => repo.restore(card.note.id),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

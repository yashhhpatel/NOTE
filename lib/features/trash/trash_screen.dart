import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/utils/snackbars.dart';
import '../../shared/widgets/empty_state.dart';
import '../notes/notes_providers.dart';
import '../notes/widgets/note_card.dart';

/// Lists trashed notes with restore and permanent-delete. Notes are also
/// auto-purged after 30 days (handled at app start).
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(trashedNotesProvider);
    final repo = ref.read(notesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Trash'),
        actions: [
          if ((notesAsync.valueOrNull ?? const []).isNotEmpty)
            TextButton(
              onPressed: () => _emptyTrash(context, repo),
              child: const Text('Empty'),
            ),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load trash: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return const EmptyState(
              icon: Icons.delete_outline,
              title: 'Trash is empty',
              message: 'Deleted notes appear here for 30 days.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Items in trash are deleted automatically after 30 days.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final card = notes[i];
                    return NoteCardTile(
                      card: card,
                      onTap: () => _showActions(context, ref, card.note.id),
                      onLongPress: () =>
                          _showActions(context, ref, card.note.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, String id) {
    final repo = ref.read(notesRepositoryProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore'),
              onTap: () {
                Navigator.pop(sheetContext);
                repo.restore(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete forever'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await _confirm(
                  context,
                  title: 'Delete forever?',
                  message: 'This note will be permanently deleted.',
                );
                if (ok) await repo.deleteForever(id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _emptyTrash(BuildContext context, repo) async {
    final ok = await _confirm(
      context,
      title: 'Empty trash?',
      message: 'All notes in trash will be permanently deleted.',
    );
    if (ok) await repo.emptyTrash();
    if (context.mounted && ok) showInfoSnackBar(context, 'Trash emptied');
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

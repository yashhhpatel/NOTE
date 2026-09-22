import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/note_card.dart';
import '../notes/notes_providers.dart';
import '../notes/widgets/note_card.dart';
import '../settings/settings_providers.dart';
import '../../shared/widgets/empty_state.dart';

/// The notes home screen: a live grid/list of active notes with search, sort
/// and settings access, plus a create menu on the FAB.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(activeNotesProvider);
    final layout = ref.watch(preferencesProvider).maybeWhen(
          data: (p) => p.layout,
          orElse: () => NoteLayout.grid,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noteflow'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            tooltip: layout == NoteLayout.grid ? 'List view' : 'Grid view',
            icon: Icon(
              layout == NoteLayout.grid ? Icons.view_agenda_outlined : Icons.grid_view,
            ),
            onPressed: () => ref.read(preferencesProvider.notifier).setLayout(
                  layout == NoteLayout.grid ? NoteLayout.list : NoteLayout.grid,
                ),
          ),
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortSheet(context, ref),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load notes: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return const EmptyState(
              icon: Icons.note_alt_outlined,
              title: 'No notes yet',
              message: 'Create your first note to get started.',
            );
          }
          return layout == NoteLayout.grid
              ? _NotesGrid(notes: notes)
              : _NotesList(notes: notes);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<NoteType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('Text note'),
              onTap: () => Navigator.pop(context, NoteType.text),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Checklist'),
              onTap: () => Navigator.pop(context, NoteType.checklist),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final defaultColor = ref.read(preferencesProvider).maybeWhen(
          data: (p) => p.defaultColorId,
          orElse: () => 0,
        );
    final note = await ref
        .read(notesRepositoryProvider)
        .createNote(type: choice, colorId: defaultColor);
    if (!context.mounted) return;
    context.push(
      choice == NoteType.checklist
          ? Routes.checklist(note.id)
          : Routes.textNote(note.id),
    );
  }

  Future<void> _showSortSheet(BuildContext context, WidgetRef ref) async {
    final current = ref.read(preferencesProvider).maybeWhen(
          data: (p) => p.sort,
          orElse: () => NoteSort.modifiedDesc,
        );
    const labels = {
      NoteSort.modifiedDesc: 'Modified (newest first)',
      NoteSort.modifiedAsc: 'Modified (oldest first)',
      NoteSort.createdDesc: 'Created (newest first)',
      NoteSort.createdAsc: 'Created (oldest first)',
      NoteSort.titleAsc: 'Title (A–Z)',
      NoteSort.titleDesc: 'Title (Z–A)',
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in labels.entries)
              RadioListTile<NoteSort>(
                value: entry.key,
                groupValue: current,
                title: Text(entry.value),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(preferencesProvider.notifier).setSort(v);
                  }
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A lightweight two-column masonry that keeps card heights natural without an
/// extra dependency. Distributes cards across two columns in order.
class _NotesGrid extends StatelessWidget {
  const _NotesGrid({required this.notes});
  final List<NoteCard> notes;

  @override
  Widget build(BuildContext context) {
    final left = <NoteCard>[];
    final right = <NoteCard>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _column(context, left)),
          const SizedBox(width: 12),
          Expanded(child: _column(context, right)),
        ],
      ),
    );
  }

  Widget _column(BuildContext context, List<NoteCard> items) {
    return Column(
      children: [
        for (final card in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HomeTile(card: card),
          ),
      ],
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({required this.notes});
  final List<NoteCard> notes;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _HomeTile(card: notes[i]),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.card});
  final NoteCard card;

  @override
  Widget build(BuildContext context) {
    return NoteCardTile(
      card: card,
      onTap: () => context.push(
        card.isChecklist
            ? Routes.checklist(card.note.id)
            : Routes.textNote(card.note.id),
      ),
      onLongPress: () {}, // Multi-select arrives in Phase 3.
    );
  }
}

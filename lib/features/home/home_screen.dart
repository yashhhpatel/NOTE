import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/app_router.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/note_card.dart';
import '../../shared/utils/snackbars.dart';
import '../../shared/widgets/color_picker_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../categories/categories_providers.dart';
import '../categories/category_picker_sheet.dart';
import '../notes/notes_providers.dart';
import '../notes/widgets/note_card.dart';
import '../settings/settings_providers.dart';
import 'widgets/home_drawer.dart';

/// The notes home screen: a live grid/list of active notes with a navigation
/// drawer, search, sort, multi-select and swipe actions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(activeNotesProvider);
    final layout = ref.watch(preferencesProvider).maybeWhen(
          data: (p) => p.layout,
          orElse: () => NoteLayout.grid,
        );
    final selection = ref.watch(selectionProvider);
    final selecting = selection.isNotEmpty;

    return Scaffold(
      appBar: selecting
          ? _selectionAppBar(context, ref, selection, notesAsync.valueOrNull)
          : _defaultAppBar(context, ref, layout),
      drawer: const HomeDrawer(),
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
              ? _NotesGrid(notes: notes, selection: selection)
              : _NotesList(notes: notes, selection: selection);
        },
      ),
      floatingActionButton: selecting
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateMenu(context, ref),
              child: const Icon(Icons.add),
            ),
    );
  }

  // --- App bars --------------------------------------------------------------

  AppBar _defaultAppBar(BuildContext context, WidgetRef ref, NoteLayout layout) {
    final filter = ref.watch(homeFilterProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final title = switch (filter) {
      HomeFilter(uncategorized: true) => 'Uncategorised',
      HomeFilter(categoryId: final id?) => categories
          .where((c) => c.id == id)
          .map((c) => c.name)
          .firstOrNull ??
          'Category',
      _ => 'Noteflow',
    };
    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(title),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          onPressed: () => context.push(Routes.search),
        ),
        IconButton(
          tooltip: layout == NoteLayout.grid ? 'List view' : 'Grid view',
          icon: Icon(layout == NoteLayout.grid
              ? Icons.view_agenda_outlined
              : Icons.grid_view),
          onPressed: () => ref.read(preferencesProvider.notifier).setLayout(
                layout == NoteLayout.grid ? NoteLayout.list : NoteLayout.grid,
              ),
        ),
        IconButton(
          tooltip: 'Sort',
          icon: const Icon(Icons.sort),
          onPressed: () => _showSortSheet(context, ref),
        ),
      ],
    );
  }

  AppBar _selectionAppBar(
    BuildContext context,
    WidgetRef ref,
    Set<String> selection,
    List<NoteCard>? notes,
  ) {
    final repo = ref.read(notesRepositoryProvider);
    final ids = selection.toList();
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => ref.read(selectionProvider.notifier).clear(),
      ),
      title: Text('${selection.length} selected'),
      actions: [
        IconButton(
          tooltip: 'Select all',
          icon: const Icon(Icons.select_all),
          onPressed: notes == null
              ? null
              : () => ref
                  .read(selectionProvider.notifier)
                  .selectAll(notes.map((c) => c.note.id)),
        ),
        IconButton(
          tooltip: 'Pin',
          icon: const Icon(Icons.push_pin_outlined),
          onPressed: () async {
            await repo.setPinnedMany(ids, true);
            ref.read(selectionProvider.notifier).clear();
          },
        ),
        IconButton(
          tooltip: 'Colour',
          icon: const Icon(Icons.palette_outlined),
          onPressed: () async {
            final picked = await showColorPicker(context, 0);
            if (picked != null) await repo.setColorMany(ids, picked);
            ref.read(selectionProvider.notifier).clear();
          },
        ),
        PopupMenuButton<String>(
          onSelected: (v) => _onSelectionMenu(context, ref, v, ids),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'move', child: Text('Move to category')),
            PopupMenuItem(value: 'archive', child: Text('Archive')),
            PopupMenuItem(value: 'share', child: Text('Share')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );
  }

  Future<void> _onSelectionMenu(
    BuildContext context,
    WidgetRef ref,
    String action,
    List<String> ids,
  ) async {
    final repo = ref.read(notesRepositoryProvider);
    switch (action) {
      case 'move':
        final choice = await showCategoryPicker(context);
        if (choice != null) {
          await repo.setCategoryMany(ids, choice.categoryId);
          ref.read(selectionProvider.notifier).clear();
          if (context.mounted) showInfoSnackBar(context, 'Moved');
        }
      case 'archive':
        await repo.setArchivedMany(ids, true);
        ref.read(selectionProvider.notifier).clear();
        if (context.mounted) {
          showUndoSnackBar(
            context,
            message: '${ids.length} archived',
            onUndo: () => repo.setArchivedMany(ids, false),
          );
        }
      case 'delete':
        await repo.moveToTrashMany(ids);
        ref.read(selectionProvider.notifier).clear();
        if (context.mounted) {
          showUndoSnackBar(
            context,
            message: '${ids.length} moved to trash',
            onUndo: () {
              for (final id in ids) {
                repo.restore(id);
              }
            },
          );
        }
      case 'share':
        final parts = <String>[];
        for (final id in ids) {
          parts.add(await repo.buildShareText(id));
        }
        ref.read(selectionProvider.notifier).clear();
        final text = parts.where((p) => p.isNotEmpty).join('\n\n---\n\n');
        if (text.isNotEmpty) await Share.share(text);
    }
  }

  // --- Create / sort ---------------------------------------------------------

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

    final prefs = ref.read(preferencesProvider).valueOrNull;
    final filter = ref.read(homeFilterProvider);
    final note = await ref.read(notesRepositoryProvider).createNote(
          type: choice,
          colorId: prefs?.defaultColorId ?? 0,
          categoryId: filter.categoryId,
        );
    if (!context.mounted) return;
    context.push(
      choice == NoteType.checklist
          ? Routes.checklist(note.id)
          : Routes.textNote(note.id),
    );
  }

  Future<void> _showSortSheet(BuildContext context, WidgetRef ref) async {
    final current = ref.read(sortProvider);
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

// --- Layouts -----------------------------------------------------------------

class _NotesGrid extends ConsumerWidget {
  const _NotesGrid({required this.notes, required this.selection});
  final List<NoteCard> notes;
  final Set<String> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Expanded(child: _column(ref, left)),
          const SizedBox(width: 12),
          Expanded(child: _column(ref, right)),
        ],
      ),
    );
  }

  Widget _column(WidgetRef ref, List<NoteCard> items) {
    return Column(
      children: [
        for (final card in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HomeTile(
              card: card,
              selected: selection.contains(card.note.id),
              selecting: selection.isNotEmpty,
            ),
          ),
      ],
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.notes, required this.selection});
  final List<NoteCard> notes;
  final Set<String> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecting = selection.isNotEmpty;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final card = notes[i];
        final tile = _HomeTile(
          card: card,
          selected: selection.contains(card.note.id),
          selecting: selecting,
        );
        if (selecting) return tile;
        // Swipe: right = archive, left = delete (both reversible via undo).
        return Dismissible(
          key: ValueKey('dismiss_${card.note.id}'),
          background: _swipeBg(
            context,
            Alignment.centerLeft,
            Icons.archive_outlined,
            'Archive',
            Colors.blueGrey,
          ),
          secondaryBackground: _swipeBg(
            context,
            Alignment.centerRight,
            Icons.delete_outline,
            'Delete',
            Colors.redAccent,
          ),
          onDismissed: (dir) {
            final repo = ref.read(notesRepositoryProvider);
            final id = card.note.id;
            if (dir == DismissDirection.startToEnd) {
              repo.setArchived(id, true);
              showUndoSnackBar(context,
                  message: 'Archived',
                  onUndo: () => repo.setArchived(id, false));
            } else {
              repo.moveToTrash(id);
              showUndoSnackBar(context,
                  message: 'Moved to trash',
                  onUndo: () => repo.restore(id));
            }
          },
          child: tile,
        );
      },
    );
  }

  Widget _swipeBg(BuildContext context, Alignment align, IconData icon,
      String label, Color color) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _HomeTile extends ConsumerWidget {
  const _HomeTile({
    required this.card,
    required this.selected,
    required this.selecting,
  });

  final NoteCard card;
  final bool selected;
  final bool selecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NoteCardTile(
      card: card,
      selected: selected,
      onTap: () {
        if (selecting) {
          ref.read(selectionProvider.notifier).toggle(card.note.id);
        } else {
          context.push(
            card.isChecklist
                ? Routes.checklist(card.note.id)
                : Routes.textNote(card.note.id),
          );
        }
      },
      onLongPress: () =>
          ref.read(selectionProvider.notifier).toggle(card.note.id),
    );
  }
}

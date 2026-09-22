import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/note_colors.dart';
import '../../data/local/database.dart';
import '../../shared/utils/snackbars.dart';
import '../../shared/widgets/color_picker_sheet.dart';
import '../categories/category_picker_sheet.dart';
import 'notes_providers.dart';

/// Editor for checklist notes: add-on-Enter, tap to toggle, drag to reorder,
/// live progress. Item edits persist immediately; the title autosaves.
class ChecklistEditor extends ConsumerStatefulWidget {
  const ChecklistEditor({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends ConsumerState<ChecklistEditor>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _itemControllers = <String, TextEditingController>{};
  final _itemFocus = <String, FocusNode>{};
  Timer? _titleDebounce;
  final _itemDebounce = <String, Timer>{};
  bool _titleInit = false;
  bool _titleDirty = false;
  String? _focusItemId;
  List<ChecklistItem> _lastItems = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleDebounce?.cancel();
    for (final t in _itemDebounce.values) {
      t.cancel();
    }
    _flushTitle();
    _titleController.dispose();
    for (final c in _itemControllers.values) {
      c.dispose();
    }
    for (final f in _itemFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushTitle();
      _flushAllItems();
    }
  }

  Future<void> _flushTitle() async {
    if (!_titleDirty) return;
    _titleDirty = false;
    await ref
        .read(notesRepositoryProvider)
        .saveTitle(widget.noteId, _titleController.text.trim());
  }

  void _flushAllItems() {
    final repo = ref.read(notesRepositoryProvider);
    for (final entry in _itemControllers.entries) {
      repo.updateItemLabel(entry.key, widget.noteId, entry.value.text);
    }
  }

  void _onTitleChanged() {
    _titleDirty = true;
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 600), _flushTitle);
  }

  void _onItemChanged(String id) {
    _itemDebounce[id]?.cancel();
    _itemDebounce[id] = Timer(const Duration(milliseconds: 500), () {
      final text = _itemControllers[id]?.text ?? '';
      ref.read(notesRepositoryProvider).updateItemLabel(id, widget.noteId, text);
    });
  }

  Future<void> _addItem() async {
    // Persist any pending edits so positions/labels are current.
    _flushAllItems();
    final item = await ref.read(notesRepositoryProvider).addItem(widget.noteId);
    _focusItemId = item.id;
  }

  Future<void> _deleteItem(String id) async {
    _itemDebounce.remove(id)?.cancel();
    _itemControllers.remove(id)?.dispose();
    _itemFocus.remove(id)?.dispose();
    await ref.read(notesRepositoryProvider).deleteItem(id, widget.noteId);
  }

  Future<void> _discardIfEmpty() async {
    final noItems = _lastItems.every((i) =>
        (_itemControllers[i.id]?.text ?? i.label).trim().isEmpty);
    if (_titleController.text.trim().isEmpty && noItems) {
      await ref.read(notesRepositoryProvider).deleteForever(widget.noteId);
    }
  }

  TextEditingController _controllerFor(ChecklistItem item) {
    final existing = _itemControllers[item.id];
    if (existing != null) return existing;
    final c = TextEditingController(text: item.label);
    _itemControllers[item.id] = c;
    return c;
  }

  FocusNode _focusFor(String id) =>
      _itemFocus.putIfAbsent(id, () => FocusNode());

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteProvider(widget.noteId));
    return noteAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not open checklist: $e')),
      ),
      data: (note) {
        if (note == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.canPop()) context.pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (!_titleInit) {
          _titleController.text = note.title;
          _titleInit = true;
        }
        return _buildScaffold(context, note);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Note note) {
    final bg = NoteColors.byId(note.colorId).background(
      Theme.of(context).brightness,
    );
    final repo = ref.read(notesRepositoryProvider);
    final itemsAsync = ref.watch(checklistItemsProvider(widget.noteId));

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        _flushAllItems();
        await _flushTitle();
        await _discardIfEmpty();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          actions: [
            IconButton(
              tooltip: note.pinned ? 'Unpin' : 'Pin',
              icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => repo.setPinned(note.id, !note.pinned),
            ),
            IconButton(
              tooltip: 'Colour',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () async {
                final picked = await showColorPicker(context, note.colorId);
                if (picked != null) await repo.setColor(note.id, picked);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _onMenu(context, v, note),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(
                    value: 'duplicate', child: Text('Duplicate')),
                const PopupMenuItem(
                    value: 'move', child: Text('Move to category')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(note.archived ? 'Unarchive' : 'Archive'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _titleController,
                  onChanged: (_) => _onTitleChanged(),
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                  ),
                ),
              ),
              itemsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (items) => _ProgressBar(items: items),
              ),
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) => _buildList(context, items),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addItem,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ChecklistItem> items) {
    _lastItems = items;
    // Focus a freshly added item once its row exists.
    if (_focusItemId != null && items.any((i) => i.id == _focusItemId)) {
      final id = _focusItemId!;
      _focusItemId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusFor(id).requestFocus();
      });
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No items yet. Tap “Add item”.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex -= 1;
        final ids = items.map((e) => e.id).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        await ref
            .read(notesRepositoryProvider)
            .reorderItems(widget.noteId, ids);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return _ChecklistRow(
          key: ValueKey(item.id),
          index: index,
          item: item,
          controller: _controllerFor(item),
          focusNode: _focusFor(item.id),
          onToggle: (v) => ref
              .read(notesRepositoryProvider)
              .setItemChecked(item.id, widget.noteId, v),
          onChanged: () => _onItemChanged(item.id),
          onSubmitted: _addItem,
          onDelete: () => _deleteItem(item.id),
        );
      },
    );
  }

  Future<void> _onMenu(BuildContext context, String value, Note note) async {
    final repo = ref.read(notesRepositoryProvider);
    switch (value) {
      case 'share':
        _flushAllItems();
        await _flushTitle();
        final text = await repo.buildShareText(note.id);
        if (text.isNotEmpty) await Share.share(text);
      case 'duplicate':
        _flushAllItems();
        await _flushTitle();
        await repo.duplicate(note.id);
        if (context.mounted) showInfoSnackBar(context, 'Duplicated');
      case 'move':
        final choice = await showCategoryPicker(context);
        if (choice != null) await repo.setCategory(note.id, choice.categoryId);
      case 'archive':
        await repo.setArchived(note.id, !note.archived);
        if (context.mounted && context.canPop()) context.pop();
      case 'delete':
        await repo.moveToTrash(note.id);
        if (context.mounted && context.canPop()) context.pop();
    }
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.items});
  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox(height: 8);
    final done = items.where((i) => i.checked).length;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Text('$done/${items.length} completed',
              style: theme.textTheme.labelMedium),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: items.isEmpty ? 0 : done / items.length,
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    super.key,
    required this.index,
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.onToggle,
    required this.onChanged,
    required this.onSubmitted,
    required this.onDelete,
  });

  final int index;
  final ChecklistItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Checkbox(
            value: item.checked,
            onChanged: (v) => onToggle(v ?? false),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSubmitted(),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration:
                    item.checked ? TextDecoration.lineThrough : null,
                color: item.checked
                    ? theme.colorScheme.onSurfaceVariant
                    : null,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'List item',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete item',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDelete,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

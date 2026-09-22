import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/note_colors.dart';
import '../../data/local/database.dart';
import '../../shared/widgets/color_picker_sheet.dart';
import 'notes_providers.dart';

/// Full-screen editor for a text note with reliable autosave:
/// debounced while typing, flushed on leave and on app backgrounding.
class TextNoteEditor extends ConsumerStatefulWidget {
  const TextNoteEditor({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<TextNoteEditor> createState() => _TextNoteEditorState();
}

class _TextNoteEditorState extends ConsumerState<TextNoteEditor>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Timer? _debounce;
  bool _initialised = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    // Best-effort final flush (fire-and-forget; DB write is quick).
    _flush();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flush();
    }
  }

  void _onChanged() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  Future<void> _flush() async {
    if (!_dirty) return;
    _dirty = false;
    await ref.read(notesRepositoryProvider).saveContent(
          widget.noteId,
          title: _titleController.text.trim(),
          content: _contentController.text,
        );
  }

  /// Deletes the note outright if the user left it completely empty.
  Future<void> _discardIfEmpty() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      await ref.read(notesRepositoryProvider).deleteForever(widget.noteId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteProvider(widget.noteId));

    return noteAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not open note: $e')),
      ),
      data: (note) {
        if (note == null) {
          // Deleted (e.g. discarded as empty) — leave the editor.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.canPop()) context.pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (!_initialised) {
          _titleController.text = note.title;
          _contentController.text = note.content;
          _initialised = true;
        }
        return _buildScaffold(context, note);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Note note) {
    final noteColor = NoteColors.byId(note.colorId);
    final bg = noteColor.background(Theme.of(context).brightness);
    final repo = ref.read(notesRepositoryProvider);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        await _flush();
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  onChanged: (_) => _onChanged(),
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                ),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    onChanged: (_) => _onChanged(),
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'Start writing…',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String value, Note note) async {
    final repo = ref.read(notesRepositoryProvider);
    switch (value) {
      case 'archive':
        await repo.setArchived(note.id, !note.archived);
        if (context.mounted && context.canPop()) context.pop();
      case 'delete':
        await _flush();
        _dirty = false;
        await repo.moveToTrash(note.id);
        if (context.mounted && context.canPop()) context.pop();
    }
  }
}

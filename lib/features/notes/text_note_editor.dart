import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/ads_service.dart';
import '../../core/theme/note_colors.dart';
import '../../data/local/database.dart';
import '../../shared/utils/snackbars.dart';
import '../billing/billing_controller.dart';
import '../../domain/text_formatting.dart';
import '../../shared/widgets/color_picker_sheet.dart';
import '../attachments/attachments_providers.dart';
import '../attachments/attachments_section.dart';
import '../categories/category_picker_sheet.dart';
import '../reminders/reminder_sheet.dart';
import '../settings/settings_providers.dart';
import 'notes_providers.dart';
import 'widgets/formatting_toolbar.dart';
import 'widgets/rich_text_controller.dart';

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
  final _contentController = RichTextEditingController();
  Timer? _debounce;
  bool _initialised = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contentController.onFormattingChanged = _onChanged;
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
    // When autosave-while-typing is off, we still flush on leave/background;
    // we just skip the periodic debounce save.
    final autosave = ref.read(preferencesProvider).maybeWhen(
          data: (p) => p.autosave,
          orElse: () => true,
        );
    if (!autosave) return;
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
          formatting: _contentController.formatting.encode(),
        );
  }

  /// Deletes the note outright if the user left it completely empty (no title,
  /// no content and no attachments).
  Future<void> _discardIfEmpty() async {
    if (_titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty) {
      return;
    }
    final attachments = await ref
        .read(attachmentsRepositoryProvider)
        .getForNote(widget.noteId);
    if (attachments.isEmpty) {
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
          _contentController.setInitialContent(
              note.content, NoteFormatting.decode(note.formatting));
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
        AdsService.instance
            .maybeShowOnTransition(isPremium: ref.read(isPremiumProvider));
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
              tooltip: 'Reminder',
              icon: Icon(note.reminderAt != null
                  ? Icons.notifications_active
                  : Icons.notifications_none),
              onPressed: () async {
                await _flush();
                if (!context.mounted) return;
                await showReminderSheet(
                  context,
                  ref,
                  noteId: note.id,
                  noteTitle: _titleController.text.trim(),
                  notePreview: _contentController.text.trim().isEmpty
                      ? 'Note reminder'
                      : _contentController.text.trim(),
                );
              },
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
                  value: 'lock',
                  child: Text(note.locked ? 'Unlock' : 'Lock'),
                ),
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
                FormattingToolbar(controller: _contentController),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _contentController,
                          onChanged: (_) => _onChanged(),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          minLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Start writing…',
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AttachmentsSection(noteId: widget.noteId),
                        const SizedBox(height: 24),
                      ],
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
      case 'share':
        await _flush();
        final text = await repo.buildShareText(note.id);
        if (text.isNotEmpty) await Share.share(text);
      case 'duplicate':
        await _flush();
        await repo.duplicate(note.id);
        if (context.mounted) showInfoSnackBar(context, 'Duplicated');
      case 'move':
        final choice = await showCategoryPicker(context);
        if (choice != null) await repo.setCategory(note.id, choice.categoryId);
      case 'lock':
        await repo.setLocked(note.id, !note.locked);
        if (context.mounted) {
          showInfoSnackBar(context, note.locked ? 'Unlocked' : 'Locked');
        }
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

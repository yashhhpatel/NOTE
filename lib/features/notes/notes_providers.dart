import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../../data/repositories/notes_repository.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/note_card.dart';
import '../settings/settings_providers.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(databaseProvider));
});

/// The current sort preference, defaulting until preferences load.
final _sortProvider = Provider<NoteSort>((ref) {
  return ref.watch(preferencesProvider).maybeWhen(
        data: (p) => p.sort,
        orElse: () => NoteSort.modifiedDesc,
      );
});

/// Reactive list of active (home) notes, re-querying when the sort changes.
final activeNotesProvider = StreamProvider.autoDispose<List<NoteCard>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  final sort = ref.watch(_sortProvider);
  return repo.watchActive(sort);
});

final archivedNotesProvider =
    StreamProvider.autoDispose<List<NoteCard>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  final sort = ref.watch(_sortProvider);
  return repo.watchArchived(sort);
});

final trashedNotesProvider = StreamProvider.autoDispose<List<NoteCard>>((ref) {
  return ref.watch(notesRepositoryProvider).watchTrashed();
});

/// Watches a single note by id (null once deleted).
final noteProvider =
    StreamProvider.autoDispose.family<Note?, String>((ref, id) {
  return ref.watch(notesRepositoryProvider).watchNote(id);
});

/// Watches the checklist items for a note, ordered by position.
final checklistItemsProvider =
    StreamProvider.autoDispose.family<List<ChecklistItem>, String>((ref, id) {
  return ref.watch(notesRepositoryProvider).watchItems(id);
});

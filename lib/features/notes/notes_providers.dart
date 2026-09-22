import 'package:flutter/foundation.dart';
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
final sortProvider = Provider<NoteSort>((ref) {
  return ref.watch(preferencesProvider).maybeWhen(
        data: (p) => p.sort,
        orElse: () => NoteSort.modifiedDesc,
      );
});

/// Which slice of notes the home screen currently shows.
@immutable
class HomeFilter {
  const HomeFilter.all()
      : categoryId = null,
        uncategorized = false;
  const HomeFilter.uncategorized()
      : categoryId = null,
        uncategorized = true;
  const HomeFilter.category(this.categoryId) : uncategorized = false;

  final String? categoryId;
  final bool uncategorized;

  @override
  bool operator ==(Object other) =>
      other is HomeFilter &&
      other.categoryId == categoryId &&
      other.uncategorized == uncategorized;

  @override
  int get hashCode => Object.hash(categoryId, uncategorized);
}

final homeFilterProvider =
    StateProvider<HomeFilter>((ref) => const HomeFilter.all());

/// Reactive list of active (home) notes, re-querying when sort or filter change.
final activeNotesProvider = StreamProvider.autoDispose<List<NoteCard>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  final sort = ref.watch(sortProvider);
  final filter = ref.watch(homeFilterProvider);
  return repo.watchActive(
    sort,
    categoryId: filter.categoryId,
    uncategorized: filter.uncategorized,
  );
});

final archivedNotesProvider =
    StreamProvider.autoDispose<List<NoteCard>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  final sort = ref.watch(sortProvider);
  return repo.watchArchived(sort);
});

final trashedNotesProvider = StreamProvider.autoDispose<List<NoteCard>>((ref) {
  return ref.watch(notesRepositoryProvider).watchTrashed();
});

// --- Search ------------------------------------------------------------------

final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final searchResultsProvider = StreamProvider.autoDispose<List<NoteCard>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final sort = ref.watch(sortProvider);
  return ref.watch(notesRepositoryProvider).watchSearch(query, sort);
});

// --- Single note / items -----------------------------------------------------

final noteProvider =
    StreamProvider.autoDispose.family<Note?, String>((ref, id) {
  return ref.watch(notesRepositoryProvider).watchNote(id);
});

final checklistItemsProvider =
    StreamProvider.autoDispose.family<List<ChecklistItem>, String>((ref, id) {
  return ref.watch(notesRepositoryProvider).watchItems(id);
});

// --- Multi-select selection state -------------------------------------------

/// Tracks which notes are selected in multi-select mode. Empty set = inactive.
class SelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  bool get isActive => state.isNotEmpty;

  void toggle(String id) {
    final next = Set<String>.from(state);
    if (!next.add(id)) next.remove(id);
    state = next;
  }

  void selectAll(Iterable<String> ids) => state = ids.toSet();

  void clear() => state = const {};
}

final selectionProvider =
    NotifierProvider<SelectionNotifier, Set<String>>(SelectionNotifier.new);

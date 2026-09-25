import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/note_card.dart';
import '../../domain/habit_tracking.dart';
import '../../domain/note_templates.dart';
import '../local/database.dart';

/// All persistence operations for notes and their checklist items.
///
/// Exposes reactive streams (Drift `.watch()`) so the UI updates automatically
/// when the underlying data changes, and imperative methods for mutations.
class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Watches the active notes for the home screen (not archived, not trashed),
  /// pinned first, then ordered by [sort]. Includes checklist progress.
  ///
  /// When [categoryId] is provided, only notes in that category are returned;
  /// pass [uncategorized] to show only notes without a category.
  Stream<List<NoteCard>> watchActive(
    NoteSort sort, {
    String? categoryId,
    bool uncategorized = false,
  }) {
    return _watchCards(
      (notes) {
        var filter = notes.archived.equals(false) & notes.trashed.equals(false);
        if (uncategorized) {
          filter = filter & notes.categoryId.isNull();
        } else if (categoryId != null) {
          filter = filter & notes.categoryId.equals(categoryId);
        }
        return filter;
      },
      sort,
      pinnedFirst: true,
    );
  }

  /// Instant local search across note title, content and checklist item text.
  /// Only searches active (non-trashed, non-archived) notes.
  Stream<List<NoteCard>> watchSearch(String query, NoteSort sort) {
    final q = query.trim();
    if (q.isEmpty) {
      return Stream.value(const []);
    }
    final pattern = '%$q%';
    return _watchCards(
      (notes) {
        final items = _db.checklistItems;
        final matchesItem = existsQuery(
          _db.select(items)
            ..where((i) =>
                i.noteId.equalsExp(notes.id) &
                i.label.like(pattern)),
        );
        final matchesText =
            notes.title.like(pattern) | notes.content.like(pattern);
        return notes.archived.equals(false) &
            notes.trashed.equals(false) &
            (matchesText | matchesItem);
      },
      sort,
      pinnedFirst: true,
    );
  }

  /// Watches archived (not trashed) notes.
  Stream<List<NoteCard>> watchArchived(NoteSort sort) {
    return _watchCards(
      (notes) => notes.archived.equals(true) & notes.trashed.equals(false),
      sort,
      pinnedFirst: false,
    );
  }

  /// Watches trashed notes, most recently trashed first.
  Stream<List<NoteCard>> watchTrashed() {
    return _watchCards(
      (notes) => notes.trashed.equals(true),
      NoteSort.modifiedDesc,
      pinnedFirst: false,
    );
  }

  Stream<List<NoteCard>> _watchCards(
    Expression<bool> Function($NotesTable notes) filter,
    NoteSort sort, {
    required bool pinnedFirst,
  }) {
    final notes = _db.notes;
    final items = _db.checklistItems;

    final total = items.id.count();
    final checked = items.id.count(filter: items.checked.equals(true));

    final query = _db.select(notes).join([
      leftOuterJoin(items, items.noteId.equalsExp(notes.id)),
    ])
      ..where(filter(notes))
      ..groupBy([notes.id]);

    query.addColumns([total, checked]);
    query.orderBy(_orderTerms(notes, sort, pinnedFirst));

    return query.watch().map((rows) {
      return rows.map((row) {
        return NoteCard(
          note: row.readTable(notes),
          checklistTotal: row.read(total) ?? 0,
          checklistChecked: row.read(checked) ?? 0,
          previewItems: const [],
        );
      }).toList();
    });
  }

  List<OrderingTerm> _orderTerms(
    $NotesTable notes,
    NoteSort sort,
    bool pinnedFirst,
  ) {
    final terms = <OrderingTerm>[];
    if (pinnedFirst) {
      terms.add(OrderingTerm(expression: notes.pinned, mode: OrderingMode.desc));
    }
    switch (sort) {
      case NoteSort.modifiedDesc:
        terms.add(OrderingTerm.desc(notes.modifiedAt));
      case NoteSort.modifiedAsc:
        terms.add(OrderingTerm.asc(notes.modifiedAt));
      case NoteSort.createdDesc:
        terms.add(OrderingTerm.desc(notes.createdAt));
      case NoteSort.createdAsc:
        terms.add(OrderingTerm.asc(notes.createdAt));
      case NoteSort.titleAsc:
        terms.add(OrderingTerm.asc(notes.title));
      case NoteSort.titleDesc:
        terms.add(OrderingTerm.desc(notes.title));
    }
    return terms;
  }

  Future<Note?> getNote(String id) =>
      (_db.select(_db.notes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Note?> watchNote(String id) =>
      (_db.select(_db.notes)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  // ---------------------------------------------------------------------------
  // Note mutations
  // ---------------------------------------------------------------------------

  /// Creates an empty note of [type] and returns its persisted row.
  Future<Note> createNote({
    required NoteType type,
    int colorId = 0,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    final companion = NotesCompanion.insert(
      id: _uuid.v4(),
      type: Value(type),
      colorId: Value(colorId),
      categoryId: Value(categoryId),
      createdAt: now,
      modifiedAt: now,
    );
    return _db.into(_db.notes).insertReturning(companion);
  }

  /// Persists edits to a text note's title/content and bumps [modifiedAt].
  /// [formatting] is the JSON-encoded bold/italic/underline ranges (see
  /// `NoteFormatting`); pass null to leave it unchanged.
  Future<void> saveContent(
    String id, {
    required String title,
    required String content,
    String? formatting,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        title: Value(title),
        content: Value(content),
        formatting:
            formatting == null ? const Value.absent() : Value(formatting),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Creates a note pre-filled from a built-in [NoteTemplate].
  Future<Note> createFromTemplate(
    NoteTemplate template, {
    int colorId = 0,
    String? categoryId,
  }) async {
    final note = await createNote(
      type: template.type,
      colorId: colorId,
      categoryId: categoryId,
    );
    if (template.type == NoteType.checklist) {
      for (final label in template.items) {
        await addItem(note.id, label: label);
      }
      await saveTitle(note.id, template.title);
    } else {
      await saveContent(note.id, title: template.title, content: template.content);
    }
    return (await getNote(note.id))!;
  }

  /// Persists just the title (used by the checklist editor).
  Future<void> saveTitle(String id, String title) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        title: Value(title),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setPinned(String id, bool pinned) => _patch(id, pinned: pinned);
  Future<void> setColor(String id, int colorId) => _patch(id, colorId: colorId);
  Future<void> setArchived(String id, bool archived) =>
      _patch(id, archived: archived);

  Future<void> setLocked(String id, bool locked) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        locked: Value(locked),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Moves a note to trash (soft delete) and records the time for auto-cleanup.
  Future<void> moveToTrash(String id) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        trashed: const Value(true),
        trashedAt: Value(DateTime.now()),
        pinned: const Value(false),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Restores a note from trash or archive back to the active list.
  Future<void> restore(String id) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        trashed: const Value(false),
        trashedAt: const Value(null),
        archived: const Value(false),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Permanently deletes a note and cascades its checklist items/attachments.
  Future<void> deleteForever(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.checklistItems)..where((t) => t.noteId.equals(id)))
          .go();
      await (_db.delete(_db.attachments)..where((t) => t.noteId.equals(id)))
          .go();
      await (_db.delete(_db.reminders)..where((t) => t.noteId.equals(id))).go();
      await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Permanently deletes every trashed note. Used by "Empty trash".
  Future<void> emptyTrash() async {
    final trashed = await (_db.select(_db.notes)
          ..where((t) => t.trashed.equals(true)))
        .get();
    await _db.transaction(() async {
      for (final note in trashed) {
        await _deleteCascade(note.id);
      }
    });
  }

  /// Auto-cleanup: permanently removes trashed notes older than [retention].
  /// Returns the number of notes purged. Safe to call on every app start.
  Future<int> purgeExpiredTrash(Duration retention) async {
    final cutoff = DateTime.now().subtract(retention);
    final expired = await (_db.select(_db.notes)
          ..where((t) =>
              t.trashed.equals(true) & t.trashedAt.isSmallerThanValue(cutoff)))
        .get();
    if (expired.isEmpty) return 0;
    await _db.transaction(() async {
      for (final note in expired) {
        await _deleteCascade(note.id);
      }
    });
    return expired.length;
  }

  /// Permanently deletes ALL note content (notes, items, reminders,
  /// attachments, categories). Used only by the "forgot PIN" safe reset, which
  /// trades access for data as the sole secure recovery path.
  Future<void> deleteAllNoteData() async {
    await _db.transaction(() async {
      await _db.delete(_db.checklistItems).go();
      await _db.delete(_db.attachments).go();
      await _db.delete(_db.reminders).go();
      await _db.delete(_db.notes).go();
      await _db.delete(_db.categories).go();
    });
  }

  Future<void> _deleteCascade(String id) async {
    await (_db.delete(_db.checklistItems)..where((t) => t.noteId.equals(id)))
        .go();
    await (_db.delete(_db.attachments)..where((t) => t.noteId.equals(id))).go();
    await (_db.delete(_db.reminders)..where((t) => t.noteId.equals(id))).go();
    await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _patch(
    String id, {
    bool? pinned,
    int? colorId,
    bool? archived,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        pinned: pinned == null ? const Value.absent() : Value(pinned),
        colorId: colorId == null ? const Value.absent() : Value(colorId),
        archived: archived == null ? const Value.absent() : Value(archived),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sets (or clears) the denormalised next-reminder time on a note.
  Future<void> setReminderAt(String id, DateTime? at) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id)))
        .write(NotesCompanion(reminderAt: Value(at)));
  }

  /// Watches non-trashed notes that have a reminder set (for the calendar).
  Stream<List<Note>> watchNotesWithReminders() {
    return (_db.select(_db.notes)
          ..where((t) => t.reminderAt.isNotNull() & t.trashed.equals(false)))
        .watch();
  }

  /// Assigns (or clears, when null) a note's category.
  Future<void> setCategory(String id, String? categoryId) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        categoryId: Value(categoryId),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  // --- Batch operations for multi-select ------------------------------------

  Future<void> setPinnedMany(Iterable<String> ids, bool pinned) =>
      _writeMany(ids, NotesCompanion(pinned: Value(pinned)));

  Future<void> setColorMany(Iterable<String> ids, int colorId) =>
      _writeMany(ids, NotesCompanion(colorId: Value(colorId)));

  Future<void> setArchivedMany(Iterable<String> ids, bool archived) =>
      _writeMany(ids, NotesCompanion(archived: Value(archived)));

  Future<void> setCategoryMany(Iterable<String> ids, String? categoryId) =>
      _writeMany(ids, NotesCompanion(categoryId: Value(categoryId)));

  Future<void> moveToTrashMany(Iterable<String> ids) => _writeMany(
        ids,
        NotesCompanion(
          trashed: const Value(true),
          trashedAt: Value(DateTime.now()),
          pinned: const Value(false),
        ),
      );

  Future<void> _writeMany(Iterable<String> ids, NotesCompanion patch) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final withTime = patch.copyWith(modifiedAt: Value(DateTime.now()));
    await _db.transaction(() async {
      for (final id in list) {
        await (_db.update(_db.notes)..where((t) => t.id.equals(id)))
            .write(withTime);
      }
    });
  }

  /// Builds a plain-text representation of a note for sharing.
  Future<String> buildShareText(String id) async {
    final note = await getNote(id);
    if (note == null) return '';
    final buffer = StringBuffer();
    if (note.title.trim().isNotEmpty) buffer.writeln(note.title.trim());
    if (note.type == NoteType.checklist) {
      final items = await watchItems(id).first;
      for (final item in items) {
        buffer.writeln('${item.checked ? '☑' : '☐'} ${item.label}');
      }
    } else if (note.content.trim().isNotEmpty) {
      buffer.writeln(note.content.trim());
    }
    return buffer.toString().trim();
  }

  /// Creates an independent copy of a note (new id) including checklist items,
  /// with fresh timestamps. Never reuses ids.
  Future<Note> duplicate(String id) async {
    return _db.transaction(() async {
      final original = await getNote(id);
      if (original == null) {
        throw StateError('Cannot duplicate missing note $id');
      }
      final now = DateTime.now();
      final newId = _uuid.v4();
      final copy = original.copyWith(
        id: newId,
        title: original.title.isEmpty ? '' : '${original.title} (copy)',
        pinned: false,
        createdAt: now,
        modifiedAt: now,
      );
      await _db.into(_db.notes).insert(copy);

      final items = await (_db.select(_db.checklistItems)
            ..where((t) => t.noteId.equals(id))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
      for (final item in items) {
        await _db.into(_db.checklistItems).insert(
              item.copyWith(id: _uuid.v4(), noteId: newId, createdAt: now),
            );
      }
      return copy;
    });
  }

  // ---------------------------------------------------------------------------
  // Checklist item mutations
  // ---------------------------------------------------------------------------

  Stream<List<ChecklistItem>> watchItems(String noteId) {
    return (_db.select(_db.checklistItems)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<ChecklistItem> addItem(String noteId, {String label = ''}) async {
    final maxPos = await _maxPosition(noteId);
    final item = ChecklistItemsCompanion.insert(
      id: _uuid.v4(),
      noteId: noteId,
      label: Value(label),
      position: Value(maxPos + 1),
      createdAt: DateTime.now(),
    );
    await _touchNote(noteId);
    return _db.into(_db.checklistItems).insertReturning(item);
  }

  Future<void> updateItemLabel(String itemId, String noteId, String label) async {
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(itemId)))
        .write(ChecklistItemsCompanion(label: Value(label)));
    await _touchNote(noteId);
  }

  Future<void> setItemChecked(
      String itemId, String noteId, bool checked) async {
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(itemId)))
        .write(ChecklistItemsCompanion(checked: Value(checked)));
    await _touchNote(noteId);
    await _maybeAdvanceHabitStreak(noteId);
  }

  // ---------------------------------------------------------------------------
  // Habit-mode checklists (auto-reset + streak)
  // ---------------------------------------------------------------------------

  Future<void> setHabitMode(String noteId, bool enabled) async {
    final now = DateTime.now();
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId))).write(
      NotesCompanion(
        habitMode: Value(enabled),
        habitStreak: const Value(0),
        habitLastCompletedDate: const Value(null),
        // Seed today's reset date so enabling mid-day doesn't immediately
        // look like a missed day next time the note is opened.
        habitLastResetDate: Value(enabled ? now : null),
        modifiedAt: Value(now),
      ),
    );
  }

  /// After a checklist item is checked/unchecked, updates the habit streak if
  /// this note is in habit mode and all items are now checked.
  Future<void> _maybeAdvanceHabitStreak(String noteId) async {
    final note = await getNote(noteId);
    if (note == null || !note.habitMode) return;
    final items = await (_db.select(_db.checklistItems)
          ..where((t) => t.noteId.equals(noteId)))
        .get();
    final allChecked = items.isNotEmpty && items.every((i) => i.checked);
    final update = HabitTracking.onItemsChanged(
      allChecked: allChecked,
      now: DateTime.now(),
      currentStreak: note.habitStreak,
      lastCompletedDate: note.habitLastCompletedDate,
    );
    if (update == null) return;
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId))).write(
      NotesCompanion(
        habitStreak: Value(update.streak),
        habitLastCompletedDate: Value(update.lastCompletedDate),
      ),
    );
  }

  /// Called when a habit-mode checklist is opened. If a new calendar day has
  /// started, unchecks all items and updates the streak (breaking it if a day
  /// was missed). No-ops for non-habit notes or if already reset today.
  Future<void> checkHabitReset(String noteId) async {
    final note = await getNote(noteId);
    if (note == null || !note.habitMode) return;
    final result = HabitTracking.resetIfNewDay(
      now: DateTime.now(),
      lastResetDate: note.habitLastResetDate,
      lastCompletedDate: note.habitLastCompletedDate,
      currentStreak: note.habitStreak,
    );
    if (result == null) return;

    await _db.transaction(() async {
      if (result.shouldUncheckItems) {
        await (_db.update(_db.checklistItems)
              ..where((t) => t.noteId.equals(noteId)))
            .write(const ChecklistItemsCompanion(checked: Value(false)));
      }
      await (_db.update(_db.notes)..where((t) => t.id.equals(noteId))).write(
        NotesCompanion(
          habitStreak: Value(result.streak),
          habitLastResetDate: Value(result.resetDate),
        ),
      );
    });
  }

  Future<void> deleteItem(String itemId, String noteId) async {
    await (_db.delete(_db.checklistItems)..where((t) => t.id.equals(itemId)))
        .go();
    await _touchNote(noteId);
  }

  /// Persists a new ordering by rewriting each item's position.
  Future<void> reorderItems(String noteId, List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.checklistItems)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(ChecklistItemsCompanion(position: Value(i)));
      }
    });
    await _touchNote(noteId);
  }

  Future<int> _maxPosition(String noteId) async {
    final items = await (_db.select(_db.checklistItems)
          ..where((t) => t.noteId.equals(noteId)))
        .get();
    if (items.isEmpty) return -1;
    return items.map((e) => e.position).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _touchNote(String noteId) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId)))
        .write(NotesCompanion(modifiedAt: Value(DateTime.now())));
  }
}

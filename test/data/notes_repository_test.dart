import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/data/repositories/notes_repository.dart';
import 'package:noteflow/domain/entities/enums.dart';

import '../util/test_db.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = NotesRepository(db);
  });

  tearDown(() => db.close());

  group('NotesRepository — notes',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('createNote inserts a note with a unique id and timestamps', () async {
      final a = await repo.createNote(type: NoteType.text);
      final b = await repo.createNote(type: NoteType.text);
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
      expect(a.type, NoteType.text);
    });

    test('saveContent updates title/content and bumps modifiedAt', () async {
      final note = await repo.createNote(type: NoteType.text);
      final before = note.modifiedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.saveContent(note.id, title: 'Hi', content: 'Body');
      final updated = await repo.getNote(note.id);
      expect(updated!.title, 'Hi');
      expect(updated.content, 'Body');
      expect(updated.modifiedAt.isAfter(before), isTrue);
    });

    test('pin / unpin toggles pinned', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setPinned(note.id, true);
      expect((await repo.getNote(note.id))!.pinned, isTrue);
      await repo.setPinned(note.id, false);
      expect((await repo.getNote(note.id))!.pinned, isFalse);
    });

    test('setColor persists the palette id', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setColor(note.id, 5);
      expect((await repo.getNote(note.id))!.colorId, 5);
    });

    test('archive / unarchive', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setArchived(note.id, true);
      expect((await repo.getNote(note.id))!.archived, isTrue);
      await repo.restore(note.id);
      expect((await repo.getNote(note.id))!.archived, isFalse);
    });

    test('moveToTrash then restore', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setPinned(note.id, true);
      await repo.moveToTrash(note.id);
      final trashed = await repo.getNote(note.id);
      expect(trashed!.trashed, isTrue);
      expect(trashed.trashedAt, isNotNull);
      expect(trashed.pinned, isFalse, reason: 'trashing unpins');
      await repo.restore(note.id);
      final restored = await repo.getNote(note.id);
      expect(restored!.trashed, isFalse);
      expect(restored.trashedAt, isNull);
    });

    test('deleteForever removes the note and its items', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.addItem(note.id, label: 'x');
      await repo.deleteForever(note.id);
      expect(await repo.getNote(note.id), isNull);
      expect(await repo.watchItems(note.id).first, isEmpty);
    });

    test('watchActive excludes archived and trashed notes', () async {
      final visible = await repo.createNote(type: NoteType.text);
      final archived = await repo.createNote(type: NoteType.text);
      final trashed = await repo.createNote(type: NoteType.text);
      await repo.setArchived(archived.id, true);
      await repo.moveToTrash(trashed.id);

      final cards = await repo.watchActive(NoteSort.modifiedDesc).first;
      final ids = cards.map((c) => c.note.id).toList();
      expect(ids, contains(visible.id));
      expect(ids, isNot(contains(archived.id)));
      expect(ids, isNot(contains(trashed.id)));
    });

    test('watchActive orders pinned notes first', () async {
      await repo.createNote(type: NoteType.text);
      final pinned = await repo.createNote(type: NoteType.text);
      await repo.setPinned(pinned.id, true);
      final cards = await repo.watchActive(NoteSort.modifiedDesc).first;
      expect(cards.first.note.id, pinned.id);
    });

    test('duplicate creates an independent copy with items', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.saveTitle(note.id, 'Groceries');
      await repo.addItem(note.id, label: 'Milk');
      await repo.addItem(note.id, label: 'Eggs');

      final copy = await repo.duplicate(note.id);
      expect(copy.id, isNot(note.id));
      expect(copy.title, 'Groceries (copy)');
      final copyItems = await repo.watchItems(copy.id).first;
      expect(copyItems.map((e) => e.label), containsAll(['Milk', 'Eggs']));

      // Editing the copy does not affect the original.
      await repo.deleteItem(copyItems.first.id, copy.id);
      final originalItems = await repo.watchItems(note.id).first;
      expect(originalItems.length, 2);
    });
  });

  group('NotesRepository — checklist',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('addItem appends with increasing positions', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      final a = await repo.addItem(note.id, label: 'A');
      final b = await repo.addItem(note.id, label: 'B');
      expect(b.position, greaterThan(a.position));
    });

    test('setItemChecked toggles completion', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      final item = await repo.addItem(note.id, label: 'A');
      await repo.setItemChecked(item.id, note.id, true);
      final items = await repo.watchItems(note.id).first;
      expect(items.single.checked, isTrue);
      await repo.setItemChecked(item.id, note.id, false);
      expect((await repo.watchItems(note.id).first).single.checked, isFalse);
    });

    test('deleteItem removes a single item', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      final a = await repo.addItem(note.id, label: 'A');
      await repo.addItem(note.id, label: 'B');
      await repo.deleteItem(a.id, note.id);
      final items = await repo.watchItems(note.id).first;
      expect(items.map((e) => e.label), ['B']);
    });

    test('reorderItems rewrites positions to match the given order', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      final a = await repo.addItem(note.id, label: 'A');
      final b = await repo.addItem(note.id, label: 'B');
      final c = await repo.addItem(note.id, label: 'C');

      await repo.reorderItems(note.id, [c.id, a.id, b.id]);
      final items = await repo.watchItems(note.id).first;
      expect(items.map((e) => e.label), ['C', 'A', 'B']);
    });

    test('checklist progress is reflected in watchActive cards', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      final a = await repo.addItem(note.id, label: 'A');
      await repo.addItem(note.id, label: 'B');
      await repo.setItemChecked(a.id, note.id, true);

      final card =
          (await repo.watchActive(NoteSort.modifiedDesc).first).single;
      expect(card.checklistTotal, 2);
      expect(card.checklistChecked, 1);
      expect(card.progress, 0.5);
    });
  });
}

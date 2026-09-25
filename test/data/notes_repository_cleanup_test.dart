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

  group('NotesRepository.purgeOrphanedEmptyNotes',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('removes a completely blank text note', () async {
      final note = await repo.createNote(type: NoteType.text);
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 1);
      expect(await repo.getNote(note.id), isNull);
    });

    test('removes a blank checklist with no items', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 1);
      expect(await repo.getNote(note.id), isNull);
    });

    test('removes a checklist whose only items are blank labels', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.addItem(note.id, label: '');
      await repo.addItem(note.id, label: '   ');
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 1);
      expect(await repo.getNote(note.id), isNull);
    });

    test('keeps a checklist that has a real item', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.addItem(note.id, label: 'Milk');
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('keeps a note that has a title', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.saveTitle(note.id, 'Ideas');
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('keeps a pinned blank note', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setPinned(note.id, true);
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('keeps a locked blank note', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setLocked(note.id, true);
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('keeps a blank note filed into a category', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setCategory(note.id, 'cat-1');
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('keeps a blank note with an attachment', () async {
      final note = await repo.createNote(type: NoteType.text);
      // Register an attachment row directly (no real file needed for this).
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: 'att-1',
              noteId: note.id,
              type: AttachmentType.image,
              path: '/tmp/x.jpg',
              createdAt: DateTime.now(),
            ),
          );
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('keeps a blank note that already has a reminder', () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.setReminderAt(note.id, DateTime(2027, 1, 1));
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('leaves a trashed blank note to the trash lifecycle instead',
        () async {
      final note = await repo.createNote(type: NoteType.text);
      await repo.moveToTrash(note.id);
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      final stillThere = await repo.getNote(note.id);
      expect(stillThere, isNotNull);
      expect(stillThere!.trashed, isTrue);
    });

    test('a habit-mode checklist with no items is kept, not purged',
        () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.setHabitMode(note.id, true);
      final purged = await repo.purgeOrphanedEmptyNotes();
      expect(purged, 0);
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('only removes the orphaned note among several', () async {
      final orphan = await repo.createNote(type: NoteType.text);
      final keeper = await repo.createNote(type: NoteType.text);
      await repo.saveContent(keeper.id, title: 'Keep me', content: '');

      final purged = await repo.purgeOrphanedEmptyNotes();

      expect(purged, 1);
      expect(await repo.getNote(orphan.id), isNull);
      expect(await repo.getNote(keeper.id), isNotNull);
    });
  });
}

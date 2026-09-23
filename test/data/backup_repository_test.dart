import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/data/repositories/backup_repository.dart';
import 'package:noteflow/data/repositories/categories_repository.dart';
import 'package:noteflow/data/repositories/notes_repository.dart';
import 'package:noteflow/domain/entities/enums.dart';

import '../util/test_db.dart';

void main() {
  late AppDatabase db;
  late BackupRepository backup;
  late NotesRepository notes;
  late CategoriesRepository categories;

  setUp(() {
    db = openTestDatabase();
    backup = BackupRepository(db);
    notes = NotesRepository(db);
    categories = CategoriesRepository(db);
  });

  tearDown(() => db.close());

  group('BackupRepository',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('validate rejects non-JSON and foreign payloads', () {
      expect(() => backup.validate('not json'),
          throwsA(isA<BackupException>()));
      expect(() => backup.validate('{"app":"other"}'),
          throwsA(isA<BackupException>()));
    });

    test('validate rejects a newer backup version', () {
      expect(
        () => backup.validate('{"app":"noteflow","backupVersion":999,'
            '"notes":[]}'),
        throwsA(isA<BackupException>()),
      );
    });

    test('export then import round-trips notes and items', () async {
      final cat = await categories.create('Work');
      final note = await notes.createNote(type: NoteType.checklist);
      await notes.saveTitle(note.id, 'Groceries');
      await notes.setCategory(note.id, cat.id);
      await notes.addItem(note.id, label: 'Milk');
      await notes.addItem(note.id, label: 'Eggs');

      final json = await backup.exportJson();

      // Wipe, then restore.
      await notes.deleteAllNoteData();
      expect(await notes.getNote(note.id), isNull);

      final imported = await backup.import(json, replace: false);
      expect(imported, 1);
      final restored = await notes.getNote(note.id);
      expect(restored, isNotNull);
      expect(restored!.title, 'Groceries');
      expect(restored.categoryId, cat.id);
      final items = await notes.watchItems(note.id).first;
      expect(items.map((e) => e.label), containsAll(['Milk', 'Eggs']));
    });

    test('merge import never creates duplicates for existing ids', () async {
      final note = await notes.createNote(type: NoteType.text);
      await notes.saveContent(note.id, title: 'Keep', content: 'x');
      final json = await backup.exportJson();

      // Import the same backup over the existing data.
      final imported = await backup.import(json, replace: false);
      expect(imported, 0, reason: 'existing note id is skipped');
      final all = await notes.watchActive(NoteSort.modifiedDesc).first;
      expect(all.where((c) => c.note.id == note.id).length, 1);
    });

    test('replace import clears existing notes first', () async {
      // Backup captured with only "backed" present.
      final backed = await notes.createNote(type: NoteType.text);
      await notes.saveContent(backed.id, title: 'Backed', content: '');
      final json = await backup.exportJson();

      // Now add a note that is NOT in the backup.
      final extra = await notes.createNote(type: NoteType.text);
      await notes.saveContent(extra.id, title: 'Extra', content: '');

      await backup.import(json, replace: true);
      // The not-backed note is wiped; the backed note is present.
      expect(await notes.getNote(extra.id), isNull);
      expect(await notes.getNote(backed.id), isNotNull);
    });

    test('exportText renders readable notes and checklists', () async {
      final note = await notes.createNote(type: NoteType.checklist);
      await notes.saveTitle(note.id, 'Trip');
      final a = await notes.addItem(note.id, label: 'Pack bags');
      await notes.setItemChecked(a.id, note.id, true);

      final text = await backup.exportText();
      expect(text, contains('Trip'));
      expect(text, contains('[x] Pack bags'));
    });
  });
}

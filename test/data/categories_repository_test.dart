import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/data/repositories/categories_repository.dart';
import 'package:noteflow/data/repositories/notes_repository.dart';
import 'package:noteflow/domain/entities/enums.dart';

import '../util/test_db.dart';

void main() {
  late AppDatabase db;
  late CategoriesRepository repo;
  late NotesRepository notes;

  setUp(() {
    db = openTestDatabase();
    repo = CategoriesRepository(db);
    notes = NotesRepository(db);
  });

  tearDown(() => db.close());

  group('CategoriesRepository',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('create and watchAll', () async {
      await repo.create('Work');
      await repo.create('Personal');
      final all = await repo.watchAll().first;
      expect(all.map((c) => c.name), containsAll(['Work', 'Personal']));
    });

    test('rename updates the name', () async {
      final c = await repo.create('Wrok');
      await repo.rename(c.id, 'Work');
      final all = await repo.getAll();
      expect(all.single.name, 'Work');
    });

    test('delete keeps notes but clears their category', () async {
      final c = await repo.create('Work');
      final note = await notes.createNote(type: NoteType.text);
      await notes.setCategory(note.id, c.id);
      expect((await notes.getNote(note.id))!.categoryId, c.id);

      await repo.delete(c.id);

      // Category gone…
      expect(await repo.getAll(), isEmpty);
      // …but the note survives and is now uncategorised.
      final survived = await notes.getNote(note.id);
      expect(survived, isNotNull);
      expect(survived!.categoryId, isNull);
    });

    test('watchCounts reflects active notes per category', () async {
      final c = await repo.create('Work');
      final a = await notes.createNote(type: NoteType.text);
      final b = await notes.createNote(type: NoteType.text);
      await notes.setCategory(a.id, c.id);
      await notes.setCategory(b.id, c.id);
      // Trashed notes are not counted.
      await notes.moveToTrash(b.id);

      final counts = await repo.watchCounts().first;
      expect(counts[c.id], 1);
    });
  });
}

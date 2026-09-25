import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/data/repositories/notes_repository.dart';
import 'package:noteflow/domain/entities/enums.dart';
import 'package:noteflow/domain/note_templates.dart';

import '../util/test_db.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = NotesRepository(db);
  });

  tearDown(() => db.close());

  group('NotesRepository — templates',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('createFromTemplate fills checklist items', () async {
      final template =
          NoteTemplates.all.firstWhere((t) => t.id == 'shopping_list');
      final note = await repo.createFromTemplate(template);
      expect(note.title, template.title);
      final items = await repo.watchItems(note.id).first;
      expect(items.map((e) => e.label), template.items);
    });

    test('createFromTemplate fills text content', () async {
      final template =
          NoteTemplates.all.firstWhere((t) => t.id == 'meeting_notes');
      final note = await repo.createFromTemplate(template);
      expect(note.type, NoteType.text);
      expect(note.content, template.content);
    });
  });

  group('NotesRepository — habit mode',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('setHabitMode initialises streak fields', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.setHabitMode(note.id, true);
      final updated = await repo.getNote(note.id);
      expect(updated!.habitMode, isTrue);
      expect(updated.habitStreak, 0);
      expect(updated.habitLastResetDate, isNotNull);
    });

    test('checking all items in a habit checklist starts a streak', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.setHabitMode(note.id, true);
      final a = await repo.addItem(note.id, label: 'Meditate');
      final b = await repo.addItem(note.id, label: 'Read');

      await repo.setItemChecked(a.id, note.id, true);
      expect((await repo.getNote(note.id))!.habitStreak, 0,
          reason: 'not all items checked yet');

      await repo.setItemChecked(b.id, note.id, true);
      final afterAll = await repo.getNote(note.id);
      expect(afterAll!.habitStreak, 1);
      expect(afterAll.habitLastCompletedDate, isNotNull);
    });

    test('non-habit checklist never touches streak fields', () async {
      final note = await repo.createNote(type: NoteType.checklist);
      final a = await repo.addItem(note.id, label: 'x');
      await repo.setItemChecked(a.id, note.id, true);
      final updated = await repo.getNote(note.id);
      expect(updated!.habitMode, isFalse);
      expect(updated.habitStreak, 0);
    });

    test('checkHabitReset uses pure logic to uncheck items on a new day',
        () async {
      final note = await repo.createNote(type: NoteType.checklist);
      await repo.setHabitMode(note.id, true);
      final a = await repo.addItem(note.id, label: 'x');
      await repo.setItemChecked(a.id, note.id, true);

      // Simulate "yesterday" by backdating the reset/completed dates directly.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await db.customStatement(
        'UPDATE notes SET habit_last_reset_date = ?, '
        'habit_last_completed_date = ? WHERE id = ?',
        [yesterday.toIso8601String(), yesterday.toIso8601String(), note.id],
      );

      await repo.checkHabitReset(note.id);

      final items = await repo.watchItems(note.id).first;
      expect(items.single.checked, isFalse);
      final updated = await repo.getNote(note.id);
      expect(updated!.habitStreak, 1, reason: 'completed yesterday, not missed');
    });
  });
}

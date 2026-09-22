import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/data/repositories/notes_repository.dart';
import 'package:noteflow/data/repositories/reminders_repository.dart';
import 'package:noteflow/domain/entities/enums.dart';

import '../util/test_db.dart';

void main() {
  late AppDatabase db;
  late RemindersRepository repo;
  late NotesRepository notes;

  setUp(() {
    db = openTestDatabase();
    repo = RemindersRepository(db);
    notes = NotesRepository(db);
  });

  tearDown(() => db.close());

  group('RemindersRepository',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    Future<String> makeNote() async =>
        (await notes.createNote(type: NoteType.text)).id;

    test('upsert creates a reminder and syncs note.reminderAt', () async {
      final noteId = await makeNote();
      final at = DateTime(2026, 5, 1, 9, 0);
      final r = await repo.upsert(noteId: noteId, triggerAt: at);
      expect(r.triggerAt, at);
      expect(r.notificationId, greaterThan(0));
      expect((await notes.getNote(noteId))!.reminderAt, at);
    });

    test('upsert twice keeps the same notification id', () async {
      final noteId = await makeNote();
      final a = await repo.upsert(
          noteId: noteId, triggerAt: DateTime(2026, 5, 1, 9, 0));
      final b = await repo.upsert(
          noteId: noteId, triggerAt: DateTime(2026, 6, 1, 9, 0));
      expect(b.notificationId, a.notificationId);
      expect(await repo.getForNote(noteId), isNotNull);
    });

    test('cancelForNote deactivates and clears the note field', () async {
      final noteId = await makeNote();
      await repo.upsert(noteId: noteId, triggerAt: DateTime(2026, 5, 1));
      await repo.cancelForNote(noteId);
      expect(await repo.getForNote(noteId), isNull);
      expect((await notes.getNote(noteId))!.reminderAt, isNull);
    });

    test('completeOccurrence deactivates a one-time reminder', () async {
      final noteId = await makeNote();
      final r = await repo.upsert(
          noteId: noteId, triggerAt: DateTime(2026, 5, 1, 9, 0));
      final result = await repo.completeOccurrence(r.id);
      expect(result, isNull);
      expect(await repo.getForNote(noteId), isNull);
      expect((await notes.getNote(noteId))!.reminderAt, isNull);
    });

    test('completeOccurrence advances a recurring reminder', () async {
      final noteId = await makeNote();
      final past =
          DateTime.now().subtract(const Duration(days: 1)).copyWith(second: 0);
      final r = await repo.upsert(
          noteId: noteId, triggerAt: past, repeat: ReminderRepeat.daily);
      final result = await repo.completeOccurrence(r.id);
      expect(result, isNotNull, reason: 'recurring reminder stays active');
      expect(result!.triggerAt.isAfter(DateTime.now()), isTrue);
      expect(await repo.getForNote(noteId), isNotNull);
    });

    test('snooze moves the trigger time forward', () async {
      final noteId = await makeNote();
      final r = await repo.upsert(
          noteId: noteId, triggerAt: DateTime(2026, 5, 1, 9, 0));
      final until = DateTime(2026, 5, 1, 9, 30);
      final snoozed = await repo.snooze(r.id, until);
      expect(snoozed!.triggerAt, until);
      expect((await notes.getNote(noteId))!.reminderAt, until);
    });
  });
}

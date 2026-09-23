import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/data/repositories/attachments_repository.dart';
import 'package:noteflow/data/repositories/notes_repository.dart';
import 'package:noteflow/domain/entities/enums.dart';

import '../util/test_db.dart';

void main() {
  late AppDatabase db;
  late AttachmentsRepository repo;
  late NotesRepository notes;

  setUp(() {
    db = openTestDatabase();
    repo = AttachmentsRepository(db);
    notes = NotesRepository(db);
  });

  tearDown(() => db.close());

  group('AttachmentsRepository',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('register records an attachment and watchForNote emits it', () async {
      final note = await notes.createNote(type: NoteType.text);
      final a = await repo.register(
        noteId: note.id,
        type: AttachmentType.audio,
        storedPath: '/data/app/noteflow/att/a.m4a',
      );
      expect(a.type, AttachmentType.audio);
      final list = await repo.watchForNote(note.id).first;
      expect(list.map((e) => e.id), [a.id]);
    });

    test('delete removes the row (missing file is ignored)', () async {
      final note = await notes.createNote(type: NoteType.text);
      final a = await repo.register(
        noteId: note.id,
        type: AttachmentType.file,
        storedPath: '/nonexistent/file.bin',
      );
      await repo.delete(a);
      expect(await repo.getForNote(note.id), isEmpty);
    });

    test('deleting a note cascades its attachment rows', () async {
      final note = await notes.createNote(type: NoteType.text);
      await repo.register(
        noteId: note.id,
        type: AttachmentType.image,
        storedPath: '/x/y.jpg',
      );
      await notes.deleteForever(note.id);
      expect(await repo.getForNote(note.id), isEmpty);
    });
  });
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/enums.dart';
import '../local/database.dart';

/// Persistence for note attachments. Files are copied into app-private
/// permanent storage (never a cache path), and the DB stores their absolute
/// paths. Deleting an attachment removes both the row and the file.
class AttachmentsRepository {
  AttachmentsRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Attachment>> watchForNote(String noteId) {
    return (_db.select(_db.attachments)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<Attachment>> getForNote(String noteId) {
    return (_db.select(_db.attachments)
          ..where((t) => t.noteId.equals(noteId)))
        .get();
  }

  /// Directory that permanently holds attachment files.
  Future<Directory> _attachmentsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into app-private storage and records the attachment.
  Future<Attachment> addFromPath({
    required String noteId,
    required AttachmentType type,
    required String sourcePath,
  }) async {
    final dir = await _attachmentsDir();
    final ext = p.extension(sourcePath);
    final id = _uuid.v4();
    final destPath = p.join(dir.path, '$id$ext');
    await File(sourcePath).copy(destPath);

    final companion = AttachmentsCompanion.insert(
      id: id,
      noteId: noteId,
      type: type,
      path: destPath,
      createdAt: DateTime.now(),
    );
    await _db.into(_db.attachments).insert(companion);
    await _touchNote(noteId);
    return (await (_db.select(_db.attachments)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// Registers a file already written inside app storage (e.g. a recording).
  Future<Attachment> register({
    required String noteId,
    required AttachmentType type,
    required String storedPath,
  }) async {
    final id = _uuid.v4();
    final companion = AttachmentsCompanion.insert(
      id: id,
      noteId: noteId,
      type: type,
      path: storedPath,
      createdAt: DateTime.now(),
    );
    await _db.into(_db.attachments).insert(companion);
    await _touchNote(noteId);
    return (await (_db.select(_db.attachments)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// A new absolute path inside attachments storage for a given extension.
  Future<String> newFilePath(String extension) async {
    final dir = await _attachmentsDir();
    return p.join(dir.path, '${_uuid.v4()}$extension');
  }

  Future<void> delete(Attachment attachment) async {
    await (_db.delete(_db.attachments)
          ..where((t) => t.id.equals(attachment.id)))
        .go();
    try {
      final file = File(attachment.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // File already gone; ignore.
    }
    await _touchNote(attachment.noteId);
  }

  Future<void> _touchNote(String noteId) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId)))
        .write(NotesCompanion(modifiedAt: Value(DateTime.now())));
  }
}

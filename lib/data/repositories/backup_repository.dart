import 'dart:convert';

import 'package:drift/drift.dart';

import '../local/database.dart';

/// Serialises and restores the entire local database as portable JSON.
///
/// No backend involved — the caller decides where to write/read the bytes
/// (a file the user picks). Restore validates and de-duplicates by id.
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  /// Current backup schema version — bumped if the JSON shape changes.
  static const int backupVersion = 1;

  /// Produces a JSON string capturing all notes, checklist items, categories,
  /// reminders and attachment metadata. Attachment binaries are referenced by
  /// path (not embedded) to keep backups small.
  Future<String> exportJson() async {
    final notes = await _db.select(_db.notes).get();
    final items = await _db.select(_db.checklistItems).get();
    final categories = await _db.select(_db.categories).get();
    final reminders = await _db.select(_db.reminders).get();
    final attachments = await _db.select(_db.attachments).get();

    final data = <String, dynamic>{
      'app': 'noteflow',
      'backupVersion': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'checklistItems': items.map((i) => i.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Produces a plain-text export of all active notes (human-readable).
  Future<String> exportText() async {
    final notes = await (_db.select(_db.notes)
          ..where((t) => t.trashed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.modifiedAt)]))
        .get();
    final buffer = StringBuffer();
    for (final note in notes) {
      if (note.title.trim().isNotEmpty) buffer.writeln(note.title.trim());
      final items = await (_db.select(_db.checklistItems)
            ..where((t) => t.noteId.equals(note.id))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
      if (items.isNotEmpty) {
        for (final i in items) {
          buffer.writeln('${i.checked ? '[x]' : '[ ]'} ${i.label}');
        }
      } else if (note.content.trim().isNotEmpty) {
        buffer.writeln(note.content.trim());
      }
      buffer.writeln('\n----------\n');
    }
    return buffer.toString();
  }

  /// Validates a backup payload without importing. Throws [BackupException]
  /// with a friendly message on malformed input.
  Map<String, dynamic> validate(String jsonStr) {
    Map<String, dynamic> map;
    try {
      map = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('This file is not a valid Noteflow backup.');
    }
    if (map['app'] != 'noteflow' || map['notes'] is! List) {
      throw const BackupException('Unrecognised backup format.');
    }
    final version = map['backupVersion'];
    if (version is int && version > backupVersion) {
      throw const BackupException(
          'This backup was made by a newer version of Noteflow.');
    }
    return map;
  }

  /// Imports a validated backup. When [replace] is true the local database is
  /// cleared first; otherwise records are merged (existing ids are skipped, so
  /// duplicates are never created). Returns the number of notes imported.
  Future<int> import(String jsonStr, {required bool replace}) async {
    final map = validate(jsonStr);
    final notes = (map['notes'] as List).cast<Map<String, dynamic>>();
    final items =
        (map['checklistItems'] as List? ?? []).cast<Map<String, dynamic>>();
    final categories =
        (map['categories'] as List? ?? []).cast<Map<String, dynamic>>();
    final reminders =
        (map['reminders'] as List? ?? []).cast<Map<String, dynamic>>();

    return _db.transaction(() async {
      if (replace) {
        await _db.delete(_db.checklistItems).go();
        await _db.delete(_db.attachments).go();
        await _db.delete(_db.reminders).go();
        await _db.delete(_db.notes).go();
        await _db.delete(_db.categories).go();
      }

      final existingNoteIds =
          (await _db.select(_db.notes).get()).map((n) => n.id).toSet();
      final existingCatIds =
          (await _db.select(_db.categories).get()).map((c) => c.id).toSet();

      var imported = 0;
      for (final json in categories) {
        final row = Category.fromJson(json);
        if (existingCatIds.contains(row.id)) continue;
        await _db.into(_db.categories).insert(row, mode: InsertMode.insertOrIgnore);
      }
      for (final json in notes) {
        final row = Note.fromJson(json);
        if (existingNoteIds.contains(row.id)) continue;
        await _db.into(_db.notes).insert(row, mode: InsertMode.insertOrIgnore);
        imported++;
      }
      for (final json in items) {
        final row = ChecklistItem.fromJson(json);
        await _db
            .into(_db.checklistItems)
            .insert(row, mode: InsertMode.insertOrIgnore);
      }
      for (final json in reminders) {
        final row = Reminder.fromJson(json);
        await _db
            .into(_db.reminders)
            .insert(row, mode: InsertMode.insertOrIgnore);
      }
      return imported;
    });
  }
}

/// Thrown when a backup file is malformed or incompatible.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

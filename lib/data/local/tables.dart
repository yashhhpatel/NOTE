import 'package:drift/drift.dart';

import '../../domain/entities/enums.dart';

/// A note — either a text note or a checklist container.
///
/// Checklist entries live in [ChecklistItems] linked by [noteId].
class Notes extends Table {
  /// UUID primary key. Stable across duplication/backup to avoid collisions.
  TextColumn get id => text()();

  IntColumn get type => intEnum<NoteType>().withDefault(const Constant(0))();

  TextColumn get title => text().withDefault(const Constant(''))();

  /// Body text for [NoteType.text]. Empty for checklists.
  TextColumn get content => text().withDefault(const Constant(''))();

  /// Index into the app colour palette (see `NoteColors`).
  IntColumn get colorId => integer().withDefault(const Constant(0))();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get trashed => boolean().withDefault(const Constant(false))();

  /// When the note was moved to trash, for auto-cleanup. Null unless trashed.
  DateTimeColumn get trashedAt => dateTime().nullable()();

  /// Whether this note requires app-lock authentication to open.
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  /// Optional category/folder membership.
  TextColumn get categoryId => text().nullable()();

  /// Denormalised next reminder time for cheap calendar/list queries.
  /// The authoritative reminder record lives in [Reminders].
  DateTimeColumn get reminderAt => dateTime().nullable()();

  /// JSON-encoded bold/italic/underline ranges over [content].
  /// See `NoteFormatting` for the shape. Null/empty means unformatted.
  TextColumn get formatting => text().nullable()();

  /// Whether this checklist auto-resets daily and tracks a streak.
  BoolColumn get habitMode => boolean().withDefault(const Constant(false))();

  /// Consecutive days this habit checklist was fully completed.
  IntColumn get habitStreak => integer().withDefault(const Constant(0))();

  /// Date (day-granularity) the checklist was last fully completed.
  DateTimeColumn get habitLastCompletedDate => dateTime().nullable()();

  /// Date (day-granularity) items were last auto-reset for a new day.
  DateTimeColumn get habitLastResetDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single checklist row belonging to a checklist [Notes] record.
class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get label => text().withDefault(const Constant(''))();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();

  /// Manual ordering within the checklist.
  IntColumn get position => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A user category / folder used to group notes.
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorId => integer().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A scheduled local reminder attached to a note.
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  DateTimeColumn get triggerAt => dateTime()();
  IntColumn get repeat =>
      intEnum<ReminderRepeat>().withDefault(const Constant(0))();

  /// Interval in days for [ReminderRepeat.custom].
  IntColumn get customIntervalDays => integer().nullable()();

  /// Stable integer id used with flutter_local_notifications.
  IntColumn get notificationId => integer()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastCompletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A file/image/audio/drawing attachment stored in app-private storage.
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  IntColumn get type => intEnum<AttachmentType>()();

  /// Absolute path inside app-private storage (never a cache path).
  TextColumn get path => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key/value store for app settings, theme, sort and notification prefs.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

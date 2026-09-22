import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/enums.dart';
import '../../domain/reminder_scheduling.dart';
import '../local/database.dart';

/// Persistence for reminders. One active reminder per note is supported.
///
/// This layer only stores reminder state and keeps the note's denormalised
/// `reminderAt` in sync. Actual OS notification scheduling is done by
/// ReminderService, which calls into this repository.
class RemindersRepository {
  RemindersRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();
  static final _random = Random();

  Future<Reminder?> getForNote(String noteId) {
    return (_db.select(_db.reminders)
          ..where((t) => t.noteId.equals(noteId) & t.active.equals(true)))
        .getSingleOrNull();
  }

  Stream<Reminder?> watchForNote(String noteId) {
    return (_db.select(_db.reminders)
          ..where((t) => t.noteId.equals(noteId) & t.active.equals(true)))
        .watchSingleOrNull();
  }

  Future<Reminder?> getById(String id) {
    return (_db.select(_db.reminders)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// All active reminders (used to reschedule after a reboot).
  Future<List<Reminder>> getActive() {
    return (_db.select(_db.reminders)..where((t) => t.active.equals(true)))
        .get();
  }

  /// Creates or replaces the reminder for a note and syncs the note's
  /// denormalised reminderAt. Returns the stored reminder.
  Future<Reminder> upsert({
    required String noteId,
    required DateTime triggerAt,
    ReminderRepeat repeat = ReminderRepeat.none,
    int? customIntervalDays,
  }) async {
    final existing = await getForNote(noteId);
    final notificationId = existing?.notificationId ?? _newNotificationId();

    final companion = RemindersCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      noteId: Value(noteId),
      triggerAt: Value(triggerAt),
      repeat: Value(repeat),
      customIntervalDays: Value(customIntervalDays),
      notificationId: Value(notificationId),
      active: const Value(true),
      lastCompletedAt: const Value(null),
      createdAt: Value(existing?.createdAt ?? DateTime.now()),
    );
    await _db.into(_db.reminders).insertOnConflictUpdate(companion);
    await _syncNoteReminder(noteId, triggerAt);
    return (await getById(companion.id.value))!;
  }

  /// Cancels a note's reminder (marks inactive and clears the note field).
  Future<void> cancelForNote(String noteId) async {
    await (_db.update(_db.reminders)..where((t) => t.noteId.equals(noteId)))
        .write(const RemindersCompanion(active: Value(false)));
    await _syncNoteReminder(noteId, null);
  }

  /// Snoozes a reminder to a new time, keeping its repeat configuration.
  Future<Reminder?> snooze(String reminderId, DateTime until) async {
    final r = await getById(reminderId);
    if (r == null) return null;
    await (_db.update(_db.reminders)..where((t) => t.id.equals(reminderId)))
        .write(RemindersCompanion(triggerAt: Value(until)));
    await _syncNoteReminder(r.noteId, until);
    return getById(reminderId);
  }

  /// Marks an occurrence complete. For recurring reminders this advances to
  /// the next occurrence (never deleting the recurring reminder); for one-time
  /// reminders it deactivates the reminder.
  ///
  /// Returns the updated reminder when it should be rescheduled, or null when
  /// the reminder is now complete/inactive.
  Future<Reminder?> completeOccurrence(String reminderId) async {
    final r = await getById(reminderId);
    if (r == null) return null;

    if (r.repeat == ReminderRepeat.none) {
      await (_db.update(_db.reminders)..where((t) => t.id.equals(reminderId)))
          .write(RemindersCompanion(
        active: const Value(false),
        lastCompletedAt: Value(DateTime.now()),
      ));
      await _syncNoteReminder(r.noteId, null);
      return null;
    }

    final next = ReminderScheduling.nextOccurrence(
      base: r.triggerAt,
      repeat: r.repeat,
      customIntervalDays: r.customIntervalDays,
      after: DateTime.now(),
    );
    if (next == null) {
      await (_db.update(_db.reminders)..where((t) => t.id.equals(reminderId)))
          .write(const RemindersCompanion(active: Value(false)));
      await _syncNoteReminder(r.noteId, null);
      return null;
    }
    await (_db.update(_db.reminders)..where((t) => t.id.equals(reminderId)))
        .write(RemindersCompanion(
      triggerAt: Value(next),
      lastCompletedAt: Value(DateTime.now()),
    ));
    await _syncNoteReminder(r.noteId, next);
    return getById(reminderId);
  }

  Future<void> _syncNoteReminder(String noteId, DateTime? at) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId)))
        .write(NotesCompanion(reminderAt: Value(at)));
  }

  /// A random positive 31-bit id suitable for the OS notification manager.
  int _newNotificationId() => _random.nextInt(1 << 30) + 1;
}

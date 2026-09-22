import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/reminder_service.dart';
import '../../data/local/database.dart';
import '../../data/repositories/reminders_repository.dart';
import '../notes/notes_providers.dart';

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(ref.watch(databaseProvider));
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService.instance;
});

/// The active reminder for a note, or null.
final reminderForNoteProvider =
    StreamProvider.autoDispose.family<Reminder?, String>((ref, noteId) {
  return ref.watch(remindersRepositoryProvider).watchForNote(noteId);
});

/// All non-trashed notes that have a reminder (drives the calendar).
final notesWithRemindersProvider =
    StreamProvider.autoDispose<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNotesWithReminders();
});

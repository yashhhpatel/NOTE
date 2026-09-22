/// Core domain enumerations for Noteflow.
///
/// Integer values are persisted in the database, so their order must remain
/// stable. Append new values at the end; never reorder or remove.
library;

/// The kind of note.
enum NoteType {
  text,
  checklist,
}

/// How a reminder repeats.
enum ReminderRepeat {
  none,
  daily,
  weekly,
  monthly,
  custom,
}

/// The type of a stored attachment.
enum AttachmentType {
  image,
  file,
  audio,
  drawing,
}

/// User-selectable sort order for the notes list.
enum NoteSort {
  modifiedDesc,
  modifiedAsc,
  createdDesc,
  createdAsc,
  titleAsc,
  titleDesc,
}

/// How notes are laid out on the home screen.
enum NoteLayout {
  grid,
  list,
}

/// The app-wide theme preference.
enum AppThemeMode {
  system,
  light,
  dark,
}

/// How long after backgrounding the app should re-lock.
enum AutoLockDelay {
  immediately,
  oneMinute,
  fiveMinutes,
  tenMinutes,
}

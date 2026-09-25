/// Pure rules for identifying an orphaned empty note — one left behind when
/// the app exits abnormally (crash, ANR, OS kill) before the editor's own
/// "discard if empty" cleanup gets a chance to run on a normal pop. Kept free
/// of Drift/Flutter so it is fully unit-testable.
class NoteCleanup {
  const NoteCleanup._();

  /// Whether a note's own fields show no sign of intentional content. A note
  /// the user pinned, locked, set a reminder on, filed into a category, or
  /// turned into a habit checklist is never considered orphaned, even if its
  /// title/content are otherwise empty — those actions are deliberate intent.
  static bool isPotentiallyOrphaned({
    required String title,
    required String content,
    required bool pinned,
    required bool locked,
    required bool habitMode,
    required DateTime? reminderAt,
    required String? categoryId,
  }) {
    return title.trim().isEmpty &&
        content.trim().isEmpty &&
        !pinned &&
        !locked &&
        !habitMode &&
        reminderAt == null &&
        categoryId == null;
  }

  /// For a checklist note already deemed [isPotentiallyOrphaned] by its own
  /// fields, whether its items also show no real content (no labels typed).
  static bool checklistHasNoContent(Iterable<String> itemLabels) {
    return itemLabels.every((label) => label.trim().isEmpty);
  }
}

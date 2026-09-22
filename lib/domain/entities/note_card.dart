import '../../data/local/database.dart';
import 'enums.dart';

/// A note plus the derived data the home list needs to render a card,
/// computed in a single aggregate query (checklist progress) so the list
/// stays fast with many notes.
class NoteCard {
  const NoteCard({
    required this.note,
    required this.checklistTotal,
    required this.checklistChecked,
    required this.previewItems,
  });

  final Note note;

  /// Total checklist items (0 for text notes).
  final int checklistTotal;

  /// Completed checklist items.
  final int checklistChecked;

  /// A few item labels for the card preview (checklist notes only).
  final List<String> previewItems;

  NoteType get type => note.type;
  bool get isChecklist => note.type == NoteType.checklist;

  /// Completion ratio in [0, 1]; 0 when there are no items.
  double get progress =>
      checklistTotal == 0 ? 0 : checklistChecked / checklistTotal;
}

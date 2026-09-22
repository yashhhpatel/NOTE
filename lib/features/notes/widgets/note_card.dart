import 'package:flutter/material.dart';

import '../../../data/local/database.dart';
import '../../../core/theme/note_colors.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/note_card.dart';
import '../../../shared/utils/date_format.dart';

/// A single note tile used in both grid and list layouts on the home screen.
class NoteCardTile extends StatelessWidget {
  const NoteCardTile({
    super.key,
    required this.card,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
  });

  final NoteCard card;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final note = card.note;
    final theme = Theme.of(context);
    final noteColor = NoteColors.byId(note.colorId);
    final bg = noteColor.background(theme.brightness);
    final onBg = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.92)
        : Colors.black.withOpacity(0.82);

    final hasTitle = note.title.trim().isNotEmpty;

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel(note, hasTitle),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
                width: selected ? 2.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasTitle ? note.title : _fallbackTitle(card),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onBg,
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              hasTitle ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                    if (note.pinned)
                      Icon(Icons.push_pin, size: 16, color: onBg),
                  ],
                ),
                const SizedBox(height: 6),
                if (card.isChecklist)
                  _ChecklistPreview(card: card, onBg: onBg)
                else if (note.content.trim().isNotEmpty)
                  Text(
                    note.content,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onBg.withOpacity(0.85),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (note.reminderAt != null) ...[
                      Icon(Icons.notifications_outlined,
                          size: 13, color: onBg.withOpacity(0.7)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      formatNoteDate(note.modifiedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onBg.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fallbackTitle(NoteCard card) =>
      card.isChecklist ? 'Checklist' : 'Note';

  String _semanticLabel(Note note, bool hasTitle) {
    final kind = note.type == NoteType.checklist ? 'Checklist' : 'Note';
    final title = hasTitle ? note.title : 'untitled';
    final pin = note.pinned ? ', pinned' : '';
    return '$kind, $title$pin';
  }
}

class _ChecklistPreview extends StatelessWidget {
  const _ChecklistPreview({required this.card, required this.onBg});
  final NoteCard card;
  final Color onBg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${card.checklistChecked}/${card.checklistTotal} done',
              style: theme.textTheme.labelSmall?.copyWith(color: onBg),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: card.progress,
                  minHeight: 5,
                  backgroundColor: onBg.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

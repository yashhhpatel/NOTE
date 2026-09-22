import 'package:flutter/material.dart';

import '../../core/theme/note_colors.dart';

/// A bottom sheet for choosing a note colour. Returns the selected palette id,
/// or null if dismissed.
Future<int?> showColorPicker(BuildContext context, int currentId) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ColorPickerSheet(currentId: currentId),
  );
}

class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet({required this.currentId});
  final int currentId;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Note colour',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in NoteColors.all)
                  _Swatch(
                    color: c.background(brightness),
                    label: c.name,
                    selected: c.id == currentId,
                    onTap: () => Navigator.of(context).pop(c.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label${selected ? ', selected' : ''}',
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check, color: scheme.primary, size: 22)
              : null,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../domain/text_formatting.dart';
import 'rich_text_controller.dart';

/// Bold / italic / underline buttons for [RichTextEditingController]. Kept
/// deliberately minimal — no alignment or font-size controls — per "don't
/// overcomplicate the editor".
class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({super.key, required this.controller});

  final RichTextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StyleButton(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              active: controller.isActive(TextStyleKind.bold),
              onPressed: () => controller.toggleStyle(TextStyleKind.bold),
            ),
            _StyleButton(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              active: controller.isActive(TextStyleKind.italic),
              onPressed: () => controller.toggleStyle(TextStyleKind.italic),
            ),
            _StyleButton(
              icon: Icons.format_underline,
              tooltip: 'Underline',
              active: controller.isActive(TextStyleKind.underline),
              onPressed: () => controller.toggleStyle(TextStyleKind.underline),
            ),
          ],
        );
      },
    );
  }
}

class _StyleButton extends StatelessWidget {
  const _StyleButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      isSelected: active,
      icon: Icon(icon),
      color: active ? scheme.primary : null,
      style: active
          ? IconButton.styleFrom(backgroundColor: scheme.primary.withOpacity(0.12))
          : null,
      onPressed: onPressed,
    );
  }
}

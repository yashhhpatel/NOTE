import 'package:flutter/material.dart';

import '../../../domain/text_formatting.dart';

/// A [TextEditingController] that renders bold/italic/underline live while
/// editing, backed by an ordinary plain-text string (the stored `content`
/// column never changes shape) plus a separately-tracked [NoteFormatting].
///
/// Edits are diffed against the previous value so format ranges shift
/// correctly as the user types, pastes or deletes.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({
    String text = '',
    NoteFormatting formatting = NoteFormatting.empty,
  })  : _formatting = formatting,
        super(text: text);

  NoteFormatting _formatting;
  NoteFormatting get formatting => _formatting;

  /// Notified whenever formatting changes (so callers can persist it).
  VoidCallback? onFormattingChanged;

  /// Sets text and formatting when loading a saved note. Uses the base
  /// implementation directly (bypassing [set value]'s diffing), so this is
  /// never mistaken for a user edit and never marks the note dirty.
  void setInitialContent(String text, NoteFormatting formatting) {
    _formatting = formatting;
    super.value = TextEditingValue(text: text);
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    if (oldText != newText) {
      _formatting = _reshapeForEdit(oldText, newText, _formatting);
      onFormattingChanged?.call();
    }
    super.value = newValue;
  }

  /// Toggles [kind] over the current selection. No-ops if there is no
  /// selection (collapsed cursor) since there is nothing to style.
  void toggleStyle(TextStyleKind kind) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final start = sel.start;
    final end = sel.end;
    _formatting = switch (kind) {
      TextStyleKind.bold => _formatting.copyWith(
          bold: TextFormattingOps.toggle(_formatting.bold, start, end)),
      TextStyleKind.italic => _formatting.copyWith(
          italic: TextFormattingOps.toggle(_formatting.italic, start, end)),
      TextStyleKind.underline => _formatting.copyWith(
          underline:
              TextFormattingOps.toggle(_formatting.underline, start, end)),
    };
    onFormattingChanged?.call();
    notifyListeners();
  }

  /// Whether the current selection is fully styled with [kind] (drives the
  /// toolbar's active/inactive button state).
  bool isActive(TextStyleKind kind) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return false;
    final ranges = switch (kind) {
      TextStyleKind.bold => _formatting.bold,
      TextStyleKind.italic => _formatting.italic,
      TextStyleKind.underline => _formatting.underline,
    };
    return TextFormattingOps.isFullyCovered(ranges, sel.start, sel.end);
  }

  static NoteFormatting _reshapeForEdit(
    String oldText,
    String newText,
    NoteFormatting fmt,
  ) {
    // Find the common prefix/suffix to isolate exactly what changed.
    var prefix = 0;
    final maxPrefix =
        oldText.length < newText.length ? oldText.length : newText.length;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText[oldSuffix - 1] == newText[newSuffix - 1]) {
      oldSuffix--;
      newSuffix--;
    }

    var bold = fmt.bold;
    var italic = fmt.italic;
    var underline = fmt.underline;

    final removedLength = oldSuffix - prefix;
    if (removedLength > 0) {
      bold = TextFormattingOps.shiftForDelete(bold, prefix, removedLength);
      italic = TextFormattingOps.shiftForDelete(italic, prefix, removedLength);
      underline =
          TextFormattingOps.shiftForDelete(underline, prefix, removedLength);
    }
    final insertedLength = newSuffix - prefix;
    if (insertedLength > 0) {
      bold = TextFormattingOps.shiftForInsert(bold, prefix, insertedLength);
      italic = TextFormattingOps.shiftForInsert(italic, prefix, insertedLength);
      underline =
          TextFormattingOps.shiftForInsert(underline, prefix, insertedLength);
    }

    return NoteFormatting(bold: bold, italic: italic, underline: underline);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) return TextSpan(style: style, text: text);
    if (_formatting.isEmpty) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }

    // Build a sequence of styled segments by walking style-change boundaries.
    final boundaries = <int>{0, text.length};
    for (final r in [..._formatting.bold, ..._formatting.italic, ..._formatting.underline]) {
      boundaries
        ..add(r.start.clamp(0, text.length))
        ..add(r.end.clamp(0, text.length));
    }
    final sortedBoundaries = boundaries.toList()..sort();

    final children = <TextSpan>[];
    for (var i = 0; i < sortedBoundaries.length - 1; i++) {
      final start = sortedBoundaries[i];
      final end = sortedBoundaries[i + 1];
      if (start >= end) continue;
      final isBold = TextFormattingOps.isFullyCovered(_formatting.bold, start, end);
      final isItalic =
          TextFormattingOps.isFullyCovered(_formatting.italic, start, end);
      final isUnderline =
          TextFormattingOps.isFullyCovered(_formatting.underline, start, end);
      children.add(TextSpan(
        text: text.substring(start, end),
        style: (style ?? const TextStyle()).copyWith(
          fontWeight: isBold ? FontWeight.bold : null,
          fontStyle: isItalic ? FontStyle.italic : null,
          decoration: isUnderline ? TextDecoration.underline : null,
        ),
      ));
    }
    return TextSpan(style: style, children: children);
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/domain/text_formatting.dart';
import 'package:noteflow/features/notes/widgets/rich_text_controller.dart';

void main() {
  group('RichTextEditingController', () {
    test('setInitialContent does not mark a formatting change', () {
      final controller = RichTextEditingController();
      var changed = false;
      controller.onFormattingChanged = () => changed = true;

      controller.setInitialContent(
        'Hello world',
        const NoteFormatting(bold: [FormatRange(0, 5)]),
      );

      expect(changed, isFalse);
      expect(controller.text, 'Hello world');
      expect(controller.formatting.bold, [const FormatRange(0, 5)]);
    });

    test('toggleStyle bolds the current selection', () {
      final controller = RichTextEditingController(text: 'Hello world');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      controller.toggleStyle(TextStyleKind.bold);
      expect(controller.formatting.bold, [const FormatRange(0, 5)]);
      expect(controller.isActive(TextStyleKind.bold), isTrue);
    });

    test('toggleStyle again removes the bold', () {
      final controller = RichTextEditingController(text: 'Hello world');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      controller.toggleStyle(TextStyleKind.bold);
      controller.toggleStyle(TextStyleKind.bold);
      expect(controller.formatting.bold, isEmpty);
    });

    test('typing before a bold range shifts it forward', () {
      final controller = RichTextEditingController();
      controller.setInitialContent(
        'world', // "world" is bold at [0,5)
        const NoteFormatting(bold: [FormatRange(0, 5)]),
      );
      controller.value = const TextEditingValue(
        text: 'Hello world',
        selection: TextSelection.collapsed(offset: 6),
      );
      // "Hello " (6 chars) inserted at position 0 -> bold shifts to [6,11).
      expect(controller.formatting.bold, [const FormatRange(6, 11)]);
    });

    test('typing inside a bold range extends it', () {
      final controller = RichTextEditingController();
      controller.setInitialContent(
        'Hlo', // bold [0,3)
        const NoteFormatting(bold: [FormatRange(0, 3)]),
      );
      // Insert "el" after "H" -> "Helo" ... let's insert at position 1.
      controller.value = const TextEditingValue(
        text: 'Helo',
        selection: TextSelection.collapsed(offset: 3),
      );
      expect(controller.formatting.bold, [const FormatRange(0, 4)]);
    });

    test('deleting text shrinks/removes overlapping ranges', () {
      final controller = RichTextEditingController();
      controller.setInitialContent(
        'Hello world',
        const NoteFormatting(bold: [FormatRange(0, 5)]),
      );
      // Delete "Hello" entirely, leaving " world".
      controller.value = const TextEditingValue(
        text: ' world',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(controller.formatting.bold, isEmpty);
    });

    test('onFormattingChanged fires on a real text edit', () {
      final controller = RichTextEditingController(text: 'abc');
      var count = 0;
      controller.onFormattingChanged = () => count++;
      controller.value = const TextEditingValue(text: 'abcd');
      expect(count, 1);
    });
  });
}

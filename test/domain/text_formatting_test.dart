import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/domain/text_formatting.dart';

void main() {
  group('TextFormattingOps.normalize', () {
    test('sorts and merges overlapping/adjacent ranges', () {
      final result = TextFormattingOps.normalize([
        const FormatRange(10, 15),
        const FormatRange(0, 5),
        const FormatRange(5, 8), // adjacent to [0,5) -> merges
        const FormatRange(12, 20), // overlaps [10,15) -> merges
      ]);
      expect(result, [const FormatRange(0, 8), const FormatRange(10, 20)]);
    });

    test('drops empty ranges', () {
      expect(TextFormattingOps.normalize([const FormatRange(5, 5)]), isEmpty);
    });
  });

  group('TextFormattingOps.isFullyCovered', () {
    test('true when a single range covers the span', () {
      expect(
        TextFormattingOps.isFullyCovered([const FormatRange(0, 10)], 2, 8),
        isTrue,
      );
    });

    test('true when multiple adjacent ranges together cover the span', () {
      expect(
        TextFormattingOps.isFullyCovered(
          [const FormatRange(0, 5), const FormatRange(5, 10)],
          2,
          8,
        ),
        isTrue,
      );
    });

    test('false when there is a gap', () {
      expect(
        TextFormattingOps.isFullyCovered(
          [const FormatRange(0, 4), const FormatRange(6, 10)],
          2,
          8,
        ),
        isFalse,
      );
    });
  });

  group('TextFormattingOps.toggle', () {
    test('adds a range when not covered', () {
      final result = TextFormattingOps.toggle([], 3, 7);
      expect(result, [const FormatRange(3, 7)]);
    });

    test('removes exactly the toggled span when fully covered', () {
      final result =
          TextFormattingOps.toggle([const FormatRange(0, 10)], 3, 7);
      expect(result, [const FormatRange(0, 3), const FormatRange(7, 10)]);
    });

    test('toggling the same range twice is a no-op overall', () {
      var ranges = TextFormattingOps.toggle([], 3, 7);
      ranges = TextFormattingOps.toggle(ranges, 3, 7);
      expect(ranges, isEmpty);
    });
  });

  group('TextFormattingOps.shiftForInsert', () {
    test('shifts ranges entirely after the insertion point', () {
      final result =
          TextFormattingOps.shiftForInsert([const FormatRange(5, 8)], 2, 3);
      expect(result, [const FormatRange(8, 11)]);
    });

    test('extends a range when typing inside it', () {
      final result =
          TextFormattingOps.shiftForInsert([const FormatRange(0, 5)], 3, 2);
      expect(result, [const FormatRange(0, 7)]);
    });

    test('leaves ranges entirely before the insertion point untouched', () {
      final result =
          TextFormattingOps.shiftForInsert([const FormatRange(0, 3)], 5, 2);
      expect(result, [const FormatRange(0, 3)]);
    });
  });

  group('TextFormattingOps.shiftForDelete', () {
    test('shifts ranges after the deleted span left by its length', () {
      final result =
          TextFormattingOps.shiftForDelete([const FormatRange(10, 15)], 2, 3);
      expect(result, [const FormatRange(7, 12)]);
    });

    test('collapses a range fully inside the deleted span', () {
      final result =
          TextFormattingOps.shiftForDelete([const FormatRange(4, 6)], 2, 5);
      expect(result, isEmpty);
    });

    test('clamps a range that straddles the deletion boundary', () {
      // Range [3,10) with deletion of [5,8) -> becomes [3,7)
      final result =
          TextFormattingOps.shiftForDelete([const FormatRange(3, 10)], 5, 3);
      expect(result, [const FormatRange(3, 7)]);
    });
  });

  group('NoteFormatting encode/decode', () {
    test('round-trips through JSON', () {
      const fmt = NoteFormatting(
        bold: [FormatRange(0, 4)],
        italic: [FormatRange(5, 9)],
        underline: [FormatRange(2, 3), FormatRange(10, 12)],
      );
      final decoded = NoteFormatting.decode(fmt.encode());
      expect(decoded.bold, fmt.bold);
      expect(decoded.italic, fmt.italic);
      expect(decoded.underline, fmt.underline);
    });

    test('decode(null) and decode("") return empty', () {
      expect(NoteFormatting.decode(null).isEmpty, isTrue);
      expect(NoteFormatting.decode('').isEmpty, isTrue);
    });

    test('decode of corrupt JSON returns empty rather than throwing', () {
      expect(NoteFormatting.decode('not json').isEmpty, isTrue);
      expect(NoteFormatting.decode('{"bold": "oops"}').isEmpty, isTrue);
    });
  });
}

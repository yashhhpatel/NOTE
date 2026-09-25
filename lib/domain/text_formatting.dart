import 'dart:convert';

/// A half-open character range `[start, end)` where a style is applied.
class FormatRange {
  const FormatRange(this.start, this.end);

  final int start;
  final int end;

  bool get isEmpty => end <= start;
  int get length => end - start;

  bool contains(int pos) => pos >= start && pos < end;

  /// Whether this range fully covers [other].
  bool covers(FormatRange other) => start <= other.start && end >= other.end;

  bool overlaps(FormatRange other) => start < other.end && end > other.start;

  List<Object> toJson() => [start, end];

  static FormatRange fromJson(Object? json) {
    final list = json! as List;
    return FormatRange((list[0] as num).toInt(), (list[1] as num).toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is FormatRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'FormatRange($start, $end)';
}

/// Bold/italic/underline character ranges over a note's plain-text content.
///
/// Stored as JSON in `notes.formatting`. The underlying content stays a plain
/// [String] column; only these ranges carry style, so search, backup/export
/// and sharing all keep working against plain text unmodified.
class NoteFormatting {
  const NoteFormatting({
    this.bold = const [],
    this.italic = const [],
    this.underline = const [],
  });

  final List<FormatRange> bold;
  final List<FormatRange> italic;
  final List<FormatRange> underline;

  static const empty = NoteFormatting();

  bool get isEmpty => bold.isEmpty && italic.isEmpty && underline.isEmpty;

  NoteFormatting copyWith({
    List<FormatRange>? bold,
    List<FormatRange>? italic,
    List<FormatRange>? underline,
  }) {
    return NoteFormatting(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
    );
  }

  String encode() => jsonEncode({
        'bold': bold.map((r) => r.toJson()).toList(),
        'italic': italic.map((r) => r.toJson()).toList(),
        'underline': underline.map((r) => r.toJson()).toList(),
      });

  static NoteFormatting decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      List<FormatRange> parse(String key) =>
          ((map[key] as List?) ?? const [])
              .map(FormatRange.fromJson)
              .toList();
      return NoteFormatting(
        bold: parse('bold'),
        italic: parse('italic'),
        underline: parse('underline'),
      );
    } catch (_) {
      return empty; // Corrupt formatting never blocks reading the note.
    }
  }
}

/// Which style a toolbar button controls.
enum TextStyleKind { bold, italic, underline }

/// Pure range algebra for the formatting toolbar and live-typing updates.
/// Kept free of Flutter/Drift so it is fully unit-testable.
class TextFormattingOps {
  const TextFormattingOps._();

  /// Merges overlapping/adjacent ranges and drops empty ones, sorted by start.
  static List<FormatRange> normalize(List<FormatRange> ranges) {
    final sorted = ranges.where((r) => !r.isEmpty).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final result = <FormatRange>[];
    for (final r in sorted) {
      if (result.isNotEmpty && r.start <= result.last.end) {
        final last = result.removeLast();
        result.add(FormatRange(last.start, r.end > last.end ? r.end : last.end));
      } else {
        result.add(r);
      }
    }
    return result;
  }

  /// Whether [start, end) is entirely covered by [ranges].
  static bool isFullyCovered(List<FormatRange> ranges, int start, int end) {
    if (end <= start) return false;
    var cursor = start;
    for (final r in normalize(ranges)) {
      if (r.start > cursor) return false;
      if (r.end > cursor) cursor = r.end;
      if (cursor >= end) return true;
    }
    return cursor >= end;
  }

  /// Toggles a style over `[start, end)`: removes it if fully applied already,
  /// otherwise adds it (merging with neighbours).
  static List<FormatRange> toggle(
    List<FormatRange> ranges,
    int start,
    int end,
  ) {
    if (end <= start) return normalize(ranges);
    if (isFullyCovered(ranges, start, end)) {
      return _subtract(ranges, start, end);
    }
    return normalize([...ranges, FormatRange(start, end)]);
  }

  static List<FormatRange> _subtract(
    List<FormatRange> ranges,
    int start,
    int end,
  ) {
    final result = <FormatRange>[];
    for (final r in ranges) {
      if (!r.overlaps(FormatRange(start, end))) {
        result.add(r);
        continue;
      }
      if (r.start < start) result.add(FormatRange(r.start, start));
      if (r.end > end) result.add(FormatRange(end, r.end));
    }
    return normalize(result);
  }

  /// Shifts ranges to account for inserting [length] characters at [at].
  /// Typing inside a styled range extends it, so the new text stays styled.
  static List<FormatRange> shiftForInsert(
    List<FormatRange> ranges,
    int at,
    int length,
  ) {
    if (length <= 0) return ranges;
    final result = <FormatRange>[];
    for (final r in ranges) {
      if (r.start >= at) {
        result.add(FormatRange(r.start + length, r.end + length));
      } else if (r.end > at) {
        result.add(FormatRange(r.start, r.end + length));
      } else {
        result.add(r);
      }
    }
    return result;
  }

  /// Shifts ranges to account for deleting [length] characters starting at
  /// [at]. Ranges fully inside the deleted span collapse (and are dropped by
  /// [normalize]-adjacent callers filtering empties).
  static List<FormatRange> shiftForDelete(
    List<FormatRange> ranges,
    int at,
    int length,
  ) {
    if (length <= 0) return ranges;
    final deletedEnd = at + length;
    int remap(int pos) {
      if (pos <= at) return pos;
      if (pos >= deletedEnd) return pos - length;
      return at;
    }

    final result = <FormatRange>[];
    for (final r in ranges) {
      final newStart = remap(r.start);
      final newEnd = remap(r.end);
      if (newEnd > newStart) result.add(FormatRange(newStart, newEnd));
    }
    return result;
  }
}

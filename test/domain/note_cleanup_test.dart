import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/domain/note_cleanup.dart';

void main() {
  group('NoteCleanup.isPotentiallyOrphaned', () {
    test('true for a completely blank, untouched note', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '',
          content: '',
          pinned: false,
          locked: false,
          habitMode: false,
          reminderAt: null,
          categoryId: null,
        ),
        isTrue,
      );
    });

    test('true when title/content are only whitespace', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '   ',
          content: '\n\t ',
          pinned: false,
          locked: false,
          habitMode: false,
          reminderAt: null,
          categoryId: null,
        ),
        isTrue,
      );
    });

    test('false when a title is present', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: 'Shopping',
          content: '',
          pinned: false,
          locked: false,
          habitMode: false,
          reminderAt: null,
          categoryId: null,
        ),
        isFalse,
      );
    });

    test('false when content is present', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '',
          content: 'Some text',
          pinned: false,
          locked: false,
          habitMode: false,
          reminderAt: null,
          categoryId: null,
        ),
        isFalse,
      );
    });

    test('false when pinned, even if otherwise empty', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '',
          content: '',
          pinned: true,
          locked: false,
          habitMode: false,
          reminderAt: null,
          categoryId: null,
        ),
        isFalse,
      );
    });

    test('false when locked', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '',
          content: '',
          pinned: false,
          locked: true,
          habitMode: false,
          reminderAt: null,
          categoryId: null,
        ),
        isFalse,
      );
    });

    test('false when in habit mode', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '',
          content: '',
          pinned: false,
          locked: false,
          habitMode: true,
          reminderAt: null,
          categoryId: null,
        ),
        isFalse,
      );
    });

    test('false when a reminder is set', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '',
          content: '',
          pinned: false,
          locked: false,
          habitMode: false,
          reminderAt: DateTime(2026, 1, 1),
          categoryId: null,
        ),
        isFalse,
      );
    });

    test('false when filed into a category', () {
      expect(
        NoteCleanup.isPotentiallyOrphaned(
          title: '',
          content: '',
          pinned: false,
          locked: false,
          habitMode: false,
          reminderAt: null,
          categoryId: 'cat-1',
        ),
        isFalse,
      );
    });
  });

  group('NoteCleanup.checklistHasNoContent', () {
    test('true for an empty list', () {
      expect(NoteCleanup.checklistHasNoContent(const []), isTrue);
    });

    test('true when every label is blank/whitespace', () {
      expect(
        NoteCleanup.checklistHasNoContent(const ['', '   ', '\n']),
        isTrue,
      );
    });

    test('false when any label has real text', () {
      expect(
        NoteCleanup.checklistHasNoContent(const ['', 'Milk', '']),
        isFalse,
      );
    });
  });
}

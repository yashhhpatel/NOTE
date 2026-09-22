import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/domain/entities/enums.dart';
import 'package:noteflow/domain/reminder_scheduling.dart';

void main() {
  group('ReminderScheduling.nextOccurrence', () {
    final now = DateTime(2026, 3, 15, 10, 0);

    test('one-time in the future returns itself', () {
      final base = DateTime(2026, 3, 20, 9, 0);
      expect(
        ReminderScheduling.nextOccurrence(
            base: base, repeat: ReminderRepeat.none, after: now),
        base,
      );
    });

    test('one-time in the past returns null', () {
      final base = DateTime(2026, 3, 10, 9, 0);
      expect(
        ReminderScheduling.nextOccurrence(
            base: base, repeat: ReminderRepeat.none, after: now),
        isNull,
      );
    });

    test('daily advances to the next future day, preserving time', () {
      // 08:30 today is before `now` (10:00), so the next occurrence is tomorrow.
      final base = DateTime(2026, 3, 10, 8, 30);
      final next = ReminderScheduling.nextOccurrence(
          base: base, repeat: ReminderRepeat.daily, after: now);
      expect(next, DateTime(2026, 3, 16, 8, 30));
      expect(next!.isAfter(now), isTrue);
    });

    test('weekly advances by 7-day steps', () {
      final base = DateTime(2026, 3, 1, 12, 0); // a Sunday
      final next = ReminderScheduling.nextOccurrence(
          base: base, repeat: ReminderRepeat.weekly, after: now);
      expect(next!.weekday, base.weekday);
      expect(next.isAfter(now), isTrue);
    });

    test('monthly keeps the day of month', () {
      final base = DateTime(2026, 1, 15, 9, 0);
      final next = ReminderScheduling.nextOccurrence(
          base: base, repeat: ReminderRepeat.monthly, after: now);
      expect(next, DateTime(2026, 4, 15, 9, 0));
    });

    test('monthly clamps day for shorter months (Jan 31 -> Feb 28)', () {
      final base = DateTime(2026, 1, 31, 9, 0);
      final after = DateTime(2026, 2, 1);
      final next = ReminderScheduling.nextOccurrence(
          base: base, repeat: ReminderRepeat.monthly, after: after);
      expect(next, DateTime(2026, 2, 28, 9, 0));
    });

    test('custom interval advances by the given number of days', () {
      final base = DateTime(2026, 3, 1, 7, 0);
      final next = ReminderScheduling.nextOccurrence(
        base: base,
        repeat: ReminderRepeat.custom,
        customIntervalDays: 3,
        after: now,
      );
      expect(next!.isAfter(now), isTrue);
      expect(next.difference(base).inDays % 3, 0);
    });
  });
}

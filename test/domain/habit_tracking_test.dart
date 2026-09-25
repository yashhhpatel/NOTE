import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/domain/habit_tracking.dart';

void main() {
  group('HabitTracking.onItemsChanged', () {
    final today = DateTime(2026, 3, 15);

    test('not fully checked -> no change', () {
      final result = HabitTracking.onItemsChanged(
        allChecked: false,
        now: today,
        currentStreak: 3,
        lastCompletedDate: null,
      );
      expect(result, isNull);
    });

    test('first-ever completion starts a streak of 1', () {
      final result = HabitTracking.onItemsChanged(
        allChecked: true,
        now: today,
        currentStreak: 0,
        lastCompletedDate: null,
      );
      expect(result!.streak, 1);
      expect(result.lastCompletedDate, DateTime(2026, 3, 15));
    });

    test('completing again the same day does not double-count', () {
      final result = HabitTracking.onItemsChanged(
        allChecked: true,
        now: today.add(const Duration(hours: 5)),
        currentStreak: 4,
        lastCompletedDate: today,
      );
      expect(result, isNull);
    });

    test('completing on the consecutive day extends the streak', () {
      final result = HabitTracking.onItemsChanged(
        allChecked: true,
        now: today,
        currentStreak: 4,
        lastCompletedDate: today.subtract(const Duration(days: 1)),
      );
      expect(result!.streak, 5);
    });

    test('completing after a gap restarts the streak at 1', () {
      final result = HabitTracking.onItemsChanged(
        allChecked: true,
        now: today,
        currentStreak: 10,
        lastCompletedDate: today.subtract(const Duration(days: 3)),
      );
      expect(result!.streak, 1);
    });
  });

  group('HabitTracking.resetIfNewDay', () {
    final today = DateTime(2026, 3, 15);
    final yesterday = today.subtract(const Duration(days: 1));

    test('no reset needed if already reset today', () {
      final result = HabitTracking.resetIfNewDay(
        now: today,
        lastResetDate: today,
        lastCompletedDate: today,
        currentStreak: 5,
      );
      expect(result, isNull);
    });

    test('new day, completed yesterday -> streak preserved, items uncheck',
        () {
      final result = HabitTracking.resetIfNewDay(
        now: today,
        lastResetDate: yesterday,
        lastCompletedDate: yesterday,
        currentStreak: 5,
      );
      expect(result!.streak, 5);
      expect(result.shouldUncheckItems, isTrue);
      expect(result.resetDate, today);
    });

    test('new day, completed today already -> streak preserved', () {
      final result = HabitTracking.resetIfNewDay(
        now: today,
        lastResetDate: null,
        lastCompletedDate: today,
        currentStreak: 3,
      );
      expect(result!.streak, 3);
    });

    test('missed a day -> streak breaks to 0', () {
      final result = HabitTracking.resetIfNewDay(
        now: today,
        lastResetDate: today.subtract(const Duration(days: 3)),
        lastCompletedDate: today.subtract(const Duration(days: 3)),
        currentStreak: 7,
      );
      expect(result!.streak, 0);
    });

    test('never completed but streak > 0 (edge case) breaks the streak', () {
      final result = HabitTracking.resetIfNewDay(
        now: today,
        lastResetDate: yesterday,
        lastCompletedDate: null,
        currentStreak: 2,
      );
      expect(result!.streak, 0);
    });
  });
}
